# Lambda Module

Provisions six Lambda functions — the document-handling Lambda, the mock validation Lambda, the SQS-triggered submit-license Lambda, and a three-step Step Functions-style pipeline (unzip → write-to-DynamoDB → compare-faces) — along with their execution roles + policies, CloudWatch log groups, and the event sources that trigger them (S3 notification for the document Lambda, SQS event source mapping for the submit-license Lambda; the unzip/write-to-dynamo/compare-faces Lambdas are invoked directly, e.g. by a Step Functions state machine or manual `aws lambda invoke`, not wired to a Terraform-managed trigger in this module).

> Resource names are env-stamped **before** they reach this module — `envs/dev/main.tf` appends `-${project_environment}` to each name input. The module itself is env-agnostic. (The validation Lambda names, and the unzip/write-to-dynamo/compare-faces IAM role/policy names, are the exception — only their **function names** are env-suffixed; role and CloudWatch-policy names are passed in **without** the suffix.)
>
> This module declares its own `required_providers` block (`aws = "~> 6.4"`) at the top of `lambda_policies.tf` — keep it a range, not an exact pin, or it will conflict with the sibling modules' constraints during `terraform init`.

## Files

- `lambda_policies.tf` — `required_providers`, IAM roles, inline policy (S3/DynamoDB/SNS), CloudWatch Logs policies + attachments, Rekognition policy + attachment, Textract policy + attachment, the submit-license SQS poll policy + attachment, and log groups for all six Lambda functions.
- `document_lambda_function.tf` — `archive_file` packaging, the document Lambda function, the S3 bucket notification, and the `lambda:InvokeFunction` permission for S3.
- `validate_lambda_function.tf` — `archive_file` packaging and the validation Lambda function (mock 3rd-party license validation).
- `submit_license_lambda_function.tf` — `archive_file` packaging, the submit-license Lambda function, and the `aws_lambda_event_source_mapping` that wires `LicenseQueue` to it (`batch_size = 1`).
- `unzip_lambda_function.tf` — `archive_file` packaging and the unzip Lambda function. No `environment` block configured (commented out) and no trigger wired in this module.
- `write_to_dynamo_lambda_function.tf` — `archive_file` packaging and the write-to-DynamoDB Lambda function. Exposes `TABLE` as a runtime env var; no trigger wired in this module.
- `compare_faces_lambda_function.tf` — `archive_file` packaging and the compare-faces Lambda function. Exposes `TABLE` and `TOPIC` as runtime env vars; no trigger wired in this module.
- `src/s3_upload.py` — Python 3.13 document-processing handler (still the monolithic pipeline triggered by the S3 `zipped/` prefix — independent of the unzip/write-to-dynamo/compare-faces split below). Full invocation flow: (1) downloads and extracts the triggering zip into `/tmp/unzipped/`, re-uploads each file to `unzipped/` in S3; (2) `parse_csv_ddb` reads `<app_uuid>_details.csv` via `csv.DictReader` + `next()` and writes the row + `APP_UUID` to DynamoDB via `put_item`; (3) `compare_faces` calls Rekognition `compare_faces` using S3 object references (not local bytes) with `SimilarityThreshold=80`, derives `LICENSE_SELFIE_MATCH = True/False` from `FaceMatches`; (4) updates the DynamoDB item with `LICENSE_SELFIE_MATCH` via `update_item`; (5) publishes a failure message to SNS if `LICENSE_SELFIE_MATCH` is `False`; (6) `textract_response` extracts the license's identity fields via `analyze_id`; (7) `compare_dictionaries` does an exact string equality check of the CSV vs Textract subsets and writes `LICENSE_DETAILS_MATCH` to DynamoDB, publishing to SNS on mismatch; (8) sends `{"driver_license_id": details_dict['DOCUMENT_NUMBER'], "validation_override": True, "uuid": app_uuid}` to `LicenseQueue` via `sqs.send_message` (JSON body), inside a `try/except ClientError` — `ClientError` is imported from `botocore.exceptions`, so a send failure is caught rather than raising `NameError`. **The handler does not raise on a mismatch** — all checks run every invocation, then the SQS message is always sent. Reads `TABLE`, `TOPIC`, and `SQS_URL` from environment variables.
- `src/validate_lambda.py` — Python 3.13 mock validation handler. Reads `driver_license_id` and `validation_override` from the API Gateway event body and returns `validation_override` directly (simulates both true and false validation outcomes).
- `src/submit_license.py` — Python 3.13 submit-license handler (`batch_size = 1`, so always `event['Records'][0]`). Parses `driver_license_id`, `validation_override`, `uuid` from the SQS record's `body`; POSTs that payload to the third-party validation endpoint at `VALIDATE_LICENSE_API_URL` via `urllib3` and waits for the response; writes `LICENSE_VALIDATION` to DynamoDB via `update_item` on `APP_UUID` for both `True`/`False` outcomes; on `False`, also publishes a failure notification to SNS. Reads `TABLE`, `TOPIC` (must be the topic **ARN**), `VALIDATE_LICENSE_API`, and `VALIDATE_LICENSE_API_URL` from environment variables.
- `src/unzip_lambda.py` — Python 3.13 unzip handler, first step of the pipeline. Expects `event['detail']['bucket']['name']` and `event['detail']['object']['key']` (e.g. `zipped/<app_uuid>.zip`). Wraps its body in `try/finally` — clears and recreates `/tmp/unzipped/` at the start (so a warm container can't leak files from a prior invocation) and always `shutil.rmtree`s it again in `finally`. `unzip_object` downloads the zip to `/tmp/`, extracts every member into `/tmp/unzipped/` (creating the dir if missing), deletes the local zip, and filters out `__`-prefixed junk (e.g. macOS's `__MACOSX`) from the returned file list. The handler re-uploads each extracted file to the `unzipped/` prefix in S3, derives `app_uuid` from the zip's filename (`os.path.basename(key).replace(".zip", "")`), and returns `{"app_uuid": app_uuid}`. No environment variables read.
- `src/write_to_dynamo_lambda.py` — Python 3.13 handler, second step of the pipeline (intended to run after the unzip Lambda, e.g. from a Step Functions state machine). Expects `event['detail']['bucket']['name']` and `event['application']['app_uuid']`. Downloads `unzipped/<app_uuid>_details.csv` from S3 to `/tmp/`, parses it with `csv.DictReader` + `next()`, and writes the row + `APP_UUID` to DynamoDB via `put_item`. Returns `{"driver_license_id": <CSV DOCUMENT_NUMBER>, "validation_override": True, "app_uuid": app_uuid}` — shaped for a downstream state to hand off to submit-license validation. Reads `TABLE` from environment variables.
- `src/compare_faces_lambda.py` — Python 3.13 handler, third step of the pipeline. Expects `event['application']['app_uuid']` and `event['detail']['bucket']['name']`; derives `unzipped/<app_uuid>_selfie.png` and `unzipped/<app_uuid>_license.png` as the S3 keys to compare. `compare_faces` calls Rekognition `compare_faces` with `SimilarityThreshold=80` (wrapped in `try/except` — any Rekognition error is logged and treated as a non-match rather than aborting the invocation), sets `LICENSE_SELFIE_MATCH` in DynamoDB via `update_item` regardless of outcome, and publishes a failure notification to SNS when the match is `False`. `lambda_handler` **raises `ValueError`** on a non-match (unlike `s3_upload.py`'s monolithic flow, which never raises) — this makes a face-match failure surface as a Lambda invocation failure, e.g. for a Step Functions `Catch` block — and otherwise returns `True`. Reads `TABLE` and `TOPIC` from environment variables.

## Resources

### Document Lambda

- `aws_iam_role.document_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"DocumentLambdaRole"` (IAM Sids must be alphanumeric).
- `aws_iam_role_policy.document_lambda_policy` — **inline** policy granting:
  - `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `${document_s3_bucket_arn}/*`
  - `dynamodb:PutItem`, `dynamodb:UpdateItem` on `${dynamodb_metadata_table_arn}`
  - `sns:Publish` on `${sns_topic_arn}`
- `aws_iam_policy.lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch: `CreateLogGroup` on `arn:aws:logs:<region>:<account>:*`; `CreateLogStream`/`PutLogEvents` scoped to `/aws/lambda/<function_name>:*`.
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_lambdaRole` — attaches the CW policy to the document Lambda role.
- `aws_iam_policy.rekognition_face_comparison_policy` — **customer-managed** policy granting `rekognition:CompareFaces` on `*`. Name is **not** env-suffixed (passed directly as `var.lambda_rekognition_face_comparison_policy_name`).
- `aws_iam_role_policy_attachment.attach_rekognition_policy_to_lambda` — attaches the Rekognition policy to the document Lambda role.
- `aws_iam_policy.textract_policy` — **customer-managed** policy granting `textract:AnalyzeID` on `*`. Name is env-suffixed via `var.lambda_textract_analyze_id_policy_name`.
- `aws_iam_role_policy_attachment.attach_textract_to_lambda` — attaches the Textract policy to the document Lambda role.
- `aws_cloudwatch_log_group.document_lambda_logs` — `/aws/lambda/<function_name>`, 14-day retention. Function name carries the env suffix, so the log group does too.
- `data.archive_file.document_lambda_function_archive_file` — zips `src/s3_upload.py` to `build/s3_upload.zip`.
- `aws_lambda_function.document_lambda_function` — Python 3.13, handler `s3_upload.lambda_handler`, wired to the log group via `logging_config`, `source_code_hash` from the archive. Exposes `TABLE`, `TOPIC`, and `SQS_URL` (the `LicenseQueue` URL, from `var.sqs_url`) as runtime env vars.
- `aws_s3_bucket_notification.document_bucket_notification` — triggers on `s3:ObjectCreated:Put` under the `zipped/` prefix.
- `aws_lambda_permission.allow_s3_invoke` — grants `s3.amazonaws.com` permission to invoke the function (`statement_id = "AllowS3Invoke"`).

### Validation Lambda

- `aws_iam_role.validation_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"ValidationLambdaRole"`. **Not env-suffixed.**
- `aws_iam_policy.validation_lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch policy, same scope pattern as the document Lambda policy. **Not env-suffixed.**
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_validationLambdaRole` — attaches the CW policy to the validation Lambda role.
- `aws_cloudwatch_log_group.validation_lambda_logs` — `/aws/lambda/<validate_lambda_function_name>`, 14-day retention.
- `data.archive_file.validate_lambda_function_archive_file` — zips `src/validate_lambda.py` to `build/validate_lambda.zip`.
- `aws_lambda_function.validation_lambda_function` — Python 3.13, handler `validate_lambda.lambda_handler`, `source_code_hash` from the archive. No logging config or environment variables configured yet.

### Submit License Lambda

- `aws_iam_role.submit_license_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"SubmitLicenseLambdaRole"`.
- `aws_iam_policy.submit_license_lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch policy, same scope pattern as the document Lambda policy.
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_submitLicenseLambdaRole` — attaches the CW policy to the submit-license role.
- `aws_iam_policy.sqs_submit_license_policy` — **customer-managed** policy granting `sqs:ReceiveMessage`/`sqs:DeleteMessage`/`sqs:GetQueueAttributes` scoped to `var.sqs_license_queue_arn` (the canonical poll permissions for an SQS-triggered Lambda; no `aws_lambda_permission` is needed because SQS is a poll source, not a push source).
- `aws_iam_role_policy_attachment.attach_AmazonSQSFullAccess` — attaches the SQS policy to the submit-license role. *(Resource label is a misnomer — it's the scoped policy above, not the AWS-managed `AmazonSQSFullAccess`.)*
- `aws_cloudwatch_log_group.submit_license_lambda_logs` — `/aws/lambda/<submit_license_lambda_function_name>`, 14-day retention.
- `data.archive_file.submit_license_lambda_function_archive_file` — zips `src/submit_license.py` to `build/submit_license.zip`.
- `aws_lambda_function.submit_license_lambda_function` — Python 3.13, handler `submit_license.lambda_handler`, wired to its log group via `logging_config`. Exposes `VALIDATE_LICENSE_API`, `VALIDATE_LICENSE_API_URL`, `TOPIC` (SNS topic ARN), and `TABLE` (DynamoDB table name) as runtime env vars.
- `aws_lambda_event_source_mapping.sqs_trigger_submit_license_lambda` — polls `var.sqs_license_queue_arn` (the `LicenseQueue`) and invokes the function with `batch_size = 1`. Enabled by default.

All submit-license names (function, role, CW policy, SQS policy) **are** env-suffixed by the caller, unlike the validation Lambda.

### Unzip Lambda

- `aws_iam_role.unzip_license_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"UnzipLicenseLambdaRole"`. **Not env-suffixed** (only the function name is).
- `aws_iam_role_policy.unzip_lambda_s3_policy` — **inline** policy granting `s3:GetObject`/`s3:PutObject` on `${document_s3_bucket_arn}/*`.
- `aws_iam_policy.unzip_license_lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch policy, same scope pattern as the document Lambda policy. **Not env-suffixed.**
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_unzipLicenseLambdaRole` — attaches the CW policy to the unzip Lambda role.
- `aws_cloudwatch_log_group.unzip_license_lambda_logs` — `/aws/lambda/<unzip_lambda_function_name>`, 14-day retention.
- `data.archive_file.unzip_lambda_function_archive_file` — zips `src/unzip_lambda.py` to `build/unzip_lambda.zip`.
- `aws_lambda_function.unzip_lambda_function` — Python 3.13, handler `unzip_lambda.lambda_handler`, wired to its log group via `logging_config`. No environment variables configured (block commented out) and no event source — invoked directly (e.g. from a Step Functions state machine).

### Write-to-DynamoDB Lambda

- `aws_iam_role.write_to_dynamo_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"WriteToDynamoLambdaRole"`. **Not env-suffixed** (only the function name is).
- `aws_iam_role_policy.write_to_dynamo_lambda_s3_policy` — **inline** policy granting `s3:GetObject` on `${document_s3_bucket_arn}/*` (downloads the details CSV only, never uploads) and `dynamodb:PutItem`/`dynamodb:UpdateItem` on `${dynamodb_metadata_table_arn}`.
- `aws_iam_policy.write_to_dynamo_lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch policy, same scope pattern as the document Lambda policy. **Not env-suffixed.**
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_writeToDynamoLambdaRole` — attaches the CW policy to the write-to-dynamo Lambda role.
- `aws_cloudwatch_log_group.write_to_dynamo_lambda_logs` — `/aws/lambda/<write_to_dynamo_lambda_function_name>`, 14-day retention.
- `data.archive_file.write_to_dynamo_lambda_function_archive_file` — zips `src/write_to_dynamo_lambda.py` to `build/write_to_dynamo_lambda.zip`.
- `aws_lambda_function.write_to_dynamo_lambda_function` — Python 3.13, handler `write_to_dynamo_lambda.lambda_handler`, wired to its log group via `logging_config`. Exposes `TABLE` as a runtime env var (`TOPIC`/`SQS_URL` inputs are commented out — unused by this handler). No event source — invoked directly.

### Compare-Faces Lambda

- `aws_iam_role.compare_faces_lambda_role` — assume-role trust for `lambda.amazonaws.com`. Trust-policy `Sid` is the literal `"CompareFacesLambdaRole"`. **Not env-suffixed** (only the function name is).
- `aws_iam_role_policy.compare_faces_lambda_policy` — **inline** policy granting `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on `${document_s3_bucket_arn}/*`, `dynamodb:PutItem`/`dynamodb:UpdateItem` on `${dynamodb_metadata_table_arn}`, and `sns:Publish` on `${sns_topic_arn}`.
- `aws_iam_policy.compare_faces_lambda_cloudwatch_logs_policy` — **customer-managed** least-privilege CloudWatch policy, same scope pattern as the document Lambda policy. **Not env-suffixed.**
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_compareFacesLambdaRole` — attaches the CW policy to the compare-faces Lambda role.
- `aws_iam_role_policy_attachment.attach_rekognition_policy_to_compare_face_lambda` — attaches the shared `rekognition_face_comparison_policy` (same customer-managed policy the document Lambda uses) to the compare-faces Lambda role.
- `aws_cloudwatch_log_group.compare_faces_lambda_logs` — `/aws/lambda/<compare_faces_lambda_function_name>`, 14-day retention.
- `data.archive_file.compare_faces_lambda_function_archive_file` — zips `src/compare_faces_lambda.py` to `build/compare_faces_lambda.zip`.
- `aws_lambda_function.compare_faces_lambda_function` — Python 3.13, handler `compare_faces_lambda.lambda_handler`, wired to its log group via `logging_config`. Exposes `TABLE` and `TOPIC` as runtime env vars. No event source — invoked directly.

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_lambda_role_name` | `string` | Full IAM role name (env-suffixed by the caller, e.g. `DocumentLambdaRole-dev`) |
| `document_lambda_policy_name` | `string` | Full inline policy name (env-suffixed) |
| `lambda_cloudwatch_logs_policy_name` | `string` | Full customer-managed CW policy name for the document Lambda (env-suffixed) |
| `document_lambda_function_name` | `string` | Full document Lambda function name (env-suffixed). Also drives the log group name and CW policy ARN scope. |
| `document_lambda_function_timeout` | `number` | Max execution time in seconds for the document Lambda |
| `validate_lambda_function_name` | `string` | Validation Lambda function name — **not** env-suffixed by the caller |
| `validate_lambda_role_name` | `string` | Validation Lambda IAM role name — **not** env-suffixed by the caller |
| `validation_lambda_cloudwatch_logs_policy_name` | `string` | CloudWatch Logs policy name for the validation Lambda — **not** env-suffixed by the caller |
| `current_region` | `string` | Region used to build region-scoped log ARNs (env passes `data.aws_region`) |
| `current_account_id` | `string` | Account ID used to build account-scoped log ARNs (env passes `data.aws_caller_identity`) |
| `document_s3_bucket_arn` | `string` | Bucket ARN — used in the inline S3 policy and as `source_arn` on the invoke permission |
| `document_s3_bucket_name` | `string` | Bucket name — used by the S3 notification resource |
| `dynamodb_metadata_table_arn` | `string` | DynamoDB table ARN — scoped in the inline policy |
| `dynamodb_document_table_name` | `string` | DynamoDB table **name** — passed to the document Lambda as the `TABLE` environment variable |
| `sns_topic_arn` | `string` | SNS topic ARN — scoped in the inline policy and used as the `TOPIC` env variable |
| `sns_topic_name` | `string` | SNS topic name — passed in but unused at runtime |
| `lambda_rekognition_face_comparison_policy_name` | `string` | Rekognition managed policy name — **not** env-suffixed by the caller |
| `lambda_textract_analyze_id_policy_name` | `string` | Textract managed policy name (env-suffixed by the caller) |
| `submit_license_lambda_function_name` | `string` | Submit-license Lambda function name (env-suffixed). Also drives its log group name and CW policy ARN scope. |
| `submit_license_lambda_role_name` | `string` | Submit-license Lambda IAM role name (env-suffixed) |
| `submit_license_lambda_cloudwatch_logs_policy_name` | `string` | CloudWatch Logs policy name for the submit-license Lambda (env-suffixed) |
| `sqs_submit_license_policy_name` | `string` | SQS poll policy name for the submit-license Lambda (env-suffixed) |
| `sqs_license_queue_arn` | `string` | `LicenseQueue` ARN — scopes the SQS poll policy and is the `event_source_arn` of the event source mapping |
| `sqs_license_queue_name` | `string` | `LicenseQueue` name — passed in for reference |
| `sqs_url` | `string` | `LicenseQueue` URL — passed to the document Lambda as the `SQS_URL` environment variable (the queue it sends the validation message to) |
| `validate_license_api_name` | `string` | API Gateway API name — passed to the submit-license Lambda as the `VALIDATE_LICENSE_API` environment variable |
| `validate_license_api_url` | `string` | API Gateway invoke URL (`POST /license`) — passed to the submit-license Lambda as the `VALIDATE_LICENSE_API_URL` environment variable, used to call the third-party validation endpoint |
| `unzip_lambda_function_name` | `string` | Unzip Lambda function name (env-suffixed by the caller). Also drives its log group name and CW policy ARN scope. |
| `unzip_lambda_function_role_name` | `string` | Unzip Lambda IAM role name — **not** env-suffixed by the caller |
| `unzip_license_lambda_cloudwatch_logs_policy_name` | `string` | CloudWatch Logs policy name for the unzip Lambda — **not** env-suffixed by the caller |
| `write_to_dynamo_lambda_function_name` | `string` | Write-to-DynamoDB Lambda function name (env-suffixed by the caller). Also drives its log group name and CW policy ARN scope. |
| `write_to_dynamo_lambda_function_role_name` | `string` | Write-to-DynamoDB Lambda IAM role name — **not** env-suffixed by the caller |
| `write_to_dynamo_lambda_cloudwatch_logs_policy_name` | `string` | CloudWatch Logs policy name for the write-to-DynamoDB Lambda — **not** env-suffixed by the caller |
| `compare_faces_lambda_function_name` | `string` | Compare-faces Lambda function name (env-suffixed by the caller). Also drives its log group name and CW policy ARN scope. |
| `compare_faces_lambda_function_role_name` | `string` | Compare-faces Lambda IAM role name — **not** env-suffixed by the caller |
| `compare_faces_lambda_cloudwatch_logs_policy_name` | `string` | CloudWatch Logs policy name for the compare-faces Lambda — **not** env-suffixed by the caller |
| `compare_faces_lambda_policy_name` | `string` | Full inline policy name for the compare-faces Lambda — **not** env-suffixed by the caller |

## Outputs

| Name | Description |
|---|---|
| `document_lambda_role_arn` | ARN of the Lambda execution role |
| `document_lambda_role_name` | Name of the Lambda execution role |
| `document_lambda_function_arn` | ARN of the Lambda function |
| `document_lambda_function_name` | Name of the Lambda function |
| `validation_lambda_invoke_arn` | Invoke ARN of the validation Lambda — consumed by the apiGateway module's `AWS_PROXY` integration |

The unzip, write-to-DynamoDB, and compare-faces Lambdas don't expose any outputs yet — nothing outside this module currently needs their ARNs/names.

## Cross-module dependencies

This module consumes values from all three sibling modules plus two env-level `data` sources. They flow through the env (sub-modules can't reference each other directly):

```
modules/s3/outputs.tf         → document_bucket_arn, document_bucket_name
modules/dynamodb/outputs.tf   → customer_metadata_table_arn, customer_metadata_table_name
modules/sns/outputs.tf        → sns_topic_arn, sns_topic_name
modules/sqs/outputs.tf        → sqs_license_queue_arn, sqs_url (→ SQS_URL on the document Lambda)
modules/apiGateway/outputs.tf → validate_license_api_name, license_validation_invoke_url
envs/dev/main.tf              → data.aws_caller_identity, data.aws_region
                               → stamps env suffix via local.env_suffix
                               → passes everything into module "document_lambda"
                               → wires customer_metadata_table_name → dynamodb_document_table_name
                               → wires sns_topic_arn → TOPIC env variable on the document, submit-license, and compare-faces Lambdas
                               → wires customer_metadata_table_name → TABLE env variable on the write-to-dynamo and compare-faces Lambdas
                               → wires license_validation_invoke_url → validate_license_api_url → VALIDATE_LICENSE_API_URL
modules/lambda/variables.tf   → receives them as var.*
```

**Watch out:** `TOPIC` must resolve to the SNS topic **ARN**, not its name — `sns:Publish` rejects the bare name with `InvalidParameter: TopicArn`.

## Notes

- The `build/` directory holds the zipped Lambda payload generated by `archive_file`. It's gitignored.
- `source_code_hash` is derived from the archive's base64 SHA-256, so any change to `src/s3_upload.py` triggers a redeploy on `terraform apply`.
- The S3 trigger is scoped to the `zipped/` prefix. The handler writes its output under `unzipped/`, so it doesn't re-trigger itself — **don't broaden the prefix filter** or you'll create an infinite invocation loop.
- The unzip/write-to-dynamo/compare-faces Lambdas form a second, separate pipeline from the monolithic `s3_upload.py` — none of the three has a Terraform-managed trigger (no S3 notification, no event source mapping), so something outside this module (e.g. a Step Functions state machine, not yet defined in this repo) must invoke them in sequence and pass each one's output into the next.
- `unzip_lambda.py` and `compare_faces_lambda.py` both derive selfie/license S3 keys as `unzipped/<app_uuid>_selfie.png` / `unzipped/<app_uuid>_license.png` — keep both in sync if the upload convention changes.