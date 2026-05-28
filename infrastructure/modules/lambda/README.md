# Lambda Module

Provisions the document-handling Lambda function, its execution role + policies, its CloudWatch log group, and the S3 event notification that triggers it.

> Resource names are env-stamped **before** they reach this module — `envs/dev/main.tf` appends `-${project_environment}` to each name input. The module itself is env-agnostic.

## Files

- `lambda_policies.tf` — IAM role, inline policy (S3/DynamoDB/SNS), customer-managed CloudWatch Logs policy + attachment, and the log group.
- `document_lambda_function.tf` — `archive_file` packaging, the Lambda function itself, the S3 bucket notification, and the `lambda:InvokeFunction` permission for S3.
- `src/s3_upload.py` — Python 3.13 handler. Full invocation flow: (1) downloads and extracts the triggering zip into `/tmp/unzipped/`, re-uploads each file to `unzipped/` in S3; (2) `parse_csv_ddb` reads `<app_uuid>_details.csv` via `csv.DictReader` + `next()` and writes the row + `APP_UUID` to DynamoDB via `put_item`; (3) `compare_faces` calls Rekognition `compare_faces` using S3 object references (not local bytes) with `SimilarityThreshold=80`, derives `LICENSE_SELFIE_MATCH = True/False` from `FaceMatches`; (4) updates the DynamoDB item with `LICENSE_SELFIE_MATCH` via `update_item`; (5) publishes a failure message to SNS if `LICENSE_SELFIE_MATCH` is `False`; (6) raises `ValueError` on mismatch so Lambda marks the invocation failed. Reads `TABLE` (DynamoDB table name) and `TOPIC` (SNS topic ARN) from environment variables at module load.

## Resources

- `aws_iam_role.document_lambda_role` — assume-role trust for `lambda.amazonaws.com`. The trust-policy `Sid` is the literal `"DocumentLambdaRole"` (IAM Sids must be alphanumeric, so it can't be derived from the env-suffixed role name).
- `aws_iam_role_policy.document_lambda_policy` — **inline** policy granting:
  - `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `${document_s3_bucket_arn}/*`
  - `dynamodb:PutItem`, `dynamodb:UpdateItem` on `${dynamodb_metadata_table_arn}`
  - `sns:Publish` on `${sns_topic_arn}`
- `aws_iam_policy.lambda_cloudwatch_logs_policy` — **customer-managed** policy, least-privilege:
  - `logs:CreateLogGroup` scoped to `arn:aws:logs:<region>:<account>:*`
  - `logs:CreateLogStream`, `logs:PutLogEvents` scoped to `/aws/lambda/<function_name>:*`
- `aws_iam_role_policy_attachment.attach_CloudWatchPolicy_to_lambdaRole` — attaches the managed CW policy to the role.
- `aws_cloudwatch_log_group.document_lambda_logs` — `/aws/lambda/<function_name>`, 14-day retention. The function name already carries the env suffix, so the log group does too.
- `data.archive_file.document_lambda_function_archive_file` — zips `src/s3_upload.py` to `build/s3_upload.zip`.
- `aws_lambda_function.document_lambda_function` — Python 3.13, handler `s3_upload.lambda_handler`, wired to the log group via `logging_config`, `source_code_hash` derived from the archive so any code change forces a redeploy. Exposes `TABLE = var.dynamodb_document_table_name` and `TOPIC = var.sns_topic_arn` as runtime environment variables.
- `aws_iam_policy.rekognition_face_comparison_policy` — **customer-managed** policy granting `rekognition:CompareFaces` on `*`. Name is **not** env-suffixed (passed directly as `var.lambda_rekognition_face_comparison_policy_name`).
- `aws_iam_role_policy_attachment.attach_rekognition_policy_to_lambda` — attaches the Rekognition policy to the role.
- `aws_s3_bucket_notification.document_bucket_notification` — triggers the function on `s3:ObjectCreated:Put` under the `zipped/` prefix.
- `aws_lambda_permission.allow_s3_invoke` — grants `s3.amazonaws.com` permission to invoke the function (`statement_id = "AllowS3Invoke"`).

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_lambda_role_name` | `string` | Full IAM role name (env-suffixed by the caller, e.g. `DocumentLambdaRole-dev`) |
| `document_lambda_policy_name` | `string` | Full inline policy name (env-suffixed) |
| `lambda_cloudwatch_logs_policy_name` | `string` | Full customer-managed CW policy name (env-suffixed) |
| `document_lambda_function_name` | `string` | Full Lambda function name (env-suffixed). Also drives the log group name and the log policy ARN scope. |
| `document_lambda_function_timeout` | `number` | Max execution time in seconds |
| `current_region` | `string` | Region used to build region-scoped log ARNs (env passes `data.aws_region`) |
| `current_account_id` | `string` | Account ID used to build account-scoped log ARNs (env passes `data.aws_caller_identity`) |
| `document_s3_bucket_arn` | `string` | Bucket ARN — used in the inline S3 policy and as `source_arn` on the invoke permission |
| `document_s3_bucket_name` | `string` | Bucket name — used by the S3 notification resource |
| `dynamodb_metadata_table_arn` | `string` | DynamoDB table ARN — scoped in the inline policy |
| `dynamodb_document_table_name` | `string` | DynamoDB table **name** — passed to the Lambda as the `TABLE` environment variable so the handler can call `dynamodb.Table(os.environ['TABLE'])` |
| `sns_topic_arn` | `string` | SNS topic ARN — scoped in the inline policy and used as the `TOPIC` env variable |
| `sns_topic_name` | `string` | SNS topic name — passed in but unused at runtime |
| `lambda_rekognition_face_comparison_policy_name` | `string` | Name of the Rekognition managed policy — **not** env-suffixed by the caller |

## Outputs

| Name | Description |
|---|---|
| `document_lambda_role_arn` | ARN of the Lambda execution role |
| `document_lambda_role_name` | Name of the Lambda execution role |
| `document_lambda_function_arn` | ARN of the Lambda function |
| `document_lambda_function_name` | Name of the Lambda function |

## Cross-module dependencies

This module consumes values from all three sibling modules plus two env-level `data` sources. They flow through the env (sub-modules can't reference each other directly):

```
modules/s3/outputs.tf       → document_bucket_arn, document_bucket_name
modules/dynamodb/outputs.tf → customer_metadata_table_arn, customer_metadata_table_name
modules/sns/outputs.tf      → sns_topic_arn, sns_topic_name
envs/dev/main.tf            → data.aws_caller_identity, data.aws_region
                             → stamps env suffix via local.env_suffix
                             → passes everything into module "document_lambda"
                             → wires customer_metadata_table_name → dynamodb_document_table_name
                             → wires sns_topic_arn → TOPIC env variable (see known issue)
modules/lambda/variables.tf → receives them as var.*
```

## Notes

- The `build/` directory holds the zipped Lambda payload generated by `archive_file`. It's gitignored.
- `source_code_hash` is derived from the archive's base64 SHA-256, so any change to `src/s3_upload.py` triggers a redeploy on `terraform apply`.
- The S3 trigger is scoped to the `zipped/` prefix. The handler writes its output under `unzipped/`, so it doesn't re-trigger itself — **don't broaden the prefix filter** or you'll create an infinite invocation loop.