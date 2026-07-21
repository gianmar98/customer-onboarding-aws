# ACI Capstone 1

AWS infrastructure for a serverless document-handling backend, provisioned entirely with Terraform.

## Stack

All resource names are stamped with `-${project_environment}` (e.g. `-dev`, `-prod`) at the env layer — see **Env-suffix naming** below.

- **S3** — document storage bucket (TLS-only, public access blocked, AES256 SSE, `force_destroy = true`). Also creates an empty `zipped/` placeholder object so the Lambda's trigger prefix exists before the first upload.
- **DynamoDB** — `CustomerMetadataTable` (provisioned capacity with optional autoscaling, partition key `APP_UUID`)
- **Lambda** — `DocumentLambdaFunction` (Python 3.13, 20 s timeout) packaged from `modules/lambda/src/` via `archive_file`. Triggered by `s3:ObjectCreated:Put` events under the `zipped/` prefix of the document bucket. On invocation the handler: (1) downloads the zip, extracts into `/tmp/unzipped/`, re-uploads each file to the `unzipped/` prefix in S3; (2) parses `<app_uuid>_details.csv` and writes the row + `APP_UUID` to DynamoDB via `put_item`; (3) calls Rekognition `compare_faces` passing selfie and license as S3 object references with `SimilarityThreshold=80`, sets `LICENSE_SELFIE_MATCH = True/False`; (4) updates the DynamoDB item with `LICENSE_SELFIE_MATCH` via `update_item`; (5) publishes to SNS if the face match failed; (6) calls Textract `analyze_id` to extract the license's identity fields; (7) exact-string-compares the CSV subset vs the Textract subset, writes `LICENSE_DETAILS_MATCH`, and publishes to SNS on mismatch; (8) sends the validation message `{"driver_license_id": <CSV DOCUMENT_NUMBER>, "validation_override": True, "uuid": <APP_UUID>}` to `LicenseQueue` via `sqs.send_message`, handing off to the submit-license Lambda. The handler **does not raise on a mismatch** — every check runs each invocation, the outcome is recorded via the two DynamoDB flags + SNS, and the SQS message is always sent. The DynamoDB table name is passed as the `TABLE` env variable, the SNS topic ARN as `TOPIC`, and the `LicenseQueue` URL as `SQS_URL` (all wired via Terraform env variables). Execution role uses an **inline** policy (S3 `Get`/`Put`/`Delete`, DynamoDB `PutItem`/`UpdateItem`, SNS `Publish`) plus three **customer-managed** policies: least-privilege CloudWatch Logs, `rekognition:CompareFaces`, and `textract:AnalyzeID`. Function owns its own `aws_cloudwatch_log_group` (`/aws/lambda/<function_name>`, 14-day retention) wired via `logging_config`. A second **validation Lambda** (`ValidateLicenseLambdaFunction`, Python 3.13, `validate_lambda.lambda_handler`) provides mock 3rd-party license validation behind the API Gateway, with its own role and CloudWatch Logs policy. A third **submit-license Lambda** (`SubmitLicenseLambdaFunction`, Python 3.13, `submit_license.lambda_handler`) is triggered by an `aws_lambda_event_source_mapping` polling `LicenseQueue` (`batch_size = 1`); its role carries a CloudWatch Logs policy and an SQS poll policy (`ReceiveMessage`/`DeleteMessage`/`GetQueueAttributes`) scoped to the queue. On invocation the handler: (1) parses the single SQS record's `body` JSON into `driver_license_id`, `validation_override`, and `uuid`; (2) POSTs that payload to the third-party validation endpoint (`VALIDATE_LICENSE_API_URL`) and waits for the response; (3) writes `LICENSE_VALIDATION` to DynamoDB via `update_item` for both `True` and `False` outcomes; (4) on `False`, also publishes a failure notification to SNS. The `TABLE` (DynamoDB table name) and `TOPIC` (SNS topic **ARN**) env vars are wired the same way as the document Lambda's. Three more Lambdas form a separate, second pipeline with no Terraform-managed trigger (invoked directly, e.g. by a Step Functions state machine not yet defined in this repo): `UnzipLambdaFunction` (`unzip_lambda.lambda_handler`) downloads+extracts the zip from `zipped/`, re-uploads to `unzipped/`, and returns the derived `app_uuid`; `WriteToDynamoLambdaFunction` (`write_to_dynamo_lambda.lambda_handler`) downloads `<app_uuid>_details.csv` from `unzipped/`, writes it to DynamoDB, and returns a `driver_license_id`/`validation_override`/`app_uuid` payload; `CompareFacesLambdaFunction` (`compare_faces_lambda.lambda_handler`) calls Rekognition `compare_faces` on the `unzipped/<app_uuid>_selfie.png` and `unzipped/<app_uuid>_license.png` objects, records `LICENSE_SELFIE_MATCH` in DynamoDB, publishes to SNS on a non-match, and **raises `ValueError` on a non-match** (unlike the monolithic document Lambda, which never raises) so a Step Functions `Catch` block can branch on it.
- **SNS** — `ApplicationNotifications` topic with email subscription, KMS-encrypted
- **API Gateway** — `ValidateLicenseApi`, an HTTP API exposing `POST /license` on the `$default` stage. An `AWS_PROXY` integration invokes `ValidateLicenseLambdaFunction`. Outputs the invoke URL as `license_validation_post_api_invoke_url`.
- **SQS** — `LicenseQueue` (standard, 300 s visibility timeout) with a redrive policy to `LicenseDeadLetterQueue` after 5 failed receives; a redrive-allow policy scopes the DLQ to that one source queue. The queue ARN (`sqs_license_queue_arn`) is wired into the lambda module to trigger the submit-license Lambda; the queue URL (`sqs_url`) is wired in as the document Lambda's `SQS_URL` env var — the document Lambda writes the validation message to the queue, closing the loop.

All resources deploy to `us-east-1`.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI configured with credentials that can assume the deployment role
- Access to the remote-state bucket `aci-capstone1-remote-state`

## Project Layout

```
.
├── infrastructure/
│   ├── modules/
│   │   ├── s3/                # Document bucket + TLS-only policy
│   │   │   ├── s3.tf
│   │   │   ├── s3_policies.tf  # TLS-only bucket policy
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── dynamodb/          # CustomerMetadataTable
│   │   │   ├── dynamodb.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── lambda/            # IAM (roles + inline + managed), 6 Lambda functions, log groups, S3 + SQS triggers
│   │   │   ├── lambda_policies.tf              # required_providers, roles, inline + managed policies, attachments, log groups
│   │   │   ├── document_lambda_function.tf     # document function, archive_file, S3 notification, invoke permission
│   │   │   ├── validate_lambda_function.tf     # validation function + archive_file
│   │   │   ├── submit_license_lambda_function.tf # submit-license function + archive_file + SQS event source mapping
│   │   │   ├── unzip_lambda_function.tf        # unzip function + archive_file (no trigger — invoked directly)
│   │   │   ├── write_to_dynamo_lambda_function.tf # write-to-dynamo function + archive_file (no trigger — invoked directly)
│   │   │   ├── compare_faces_lambda_function.tf   # compare-faces function + archive_file (no trigger — invoked directly)
│   │   │   ├── src/                            # Python handlers (s3_upload.py, validate_lambda.py, submit_license.py, unzip_lambda.py, write_to_dynamo_lambda.py, compare_faces_lambda.py)
│   │   │   ├── build/                      # archive_file zip output (gitignored)
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── sns/               # ApplicationNotifications topic + email sub
│   │   │   ├── sns.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── apiGateway/        # ValidateLicenseApi HTTP API (POST /license) -> validation Lambda
│   │   │   ├── apigw.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── sqs/               # LicenseQueue + LicenseDeadLetterQueue (DLQ)
│   │       ├── sqs.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf      # exposes queue arn, DLQ arn, queue name, queue url
│   │       └── README.md
│   └── envs/
│       └── dev/
│           ├── backend.tf       # state at envs/dev/terraform.tfstate
│           ├── main.tf          # composes all 6 sub-modules
│           ├── variables.tf     # pass-through declarations
│           ├── outputs.tf       # forwards each sub-module's outputs
│           └── terraform.tfvars # gitignored
└── frontend/                # (placeholder — not yet implemented)
```

The structure is **per-resource sub-modules composed by the env**. Only `dev` exists today; a `prod` env can be added later by copying `dev/`, swapping the backend `key`, and setting `project_environment = "prod"` in the new `terraform.tfvars` — the base names stay identical and the env-suffix pattern (see below) makes every resource land as `*-prod` automatically.

## Env-suffix naming

Every resource name passed into a module is stamped with `-${var.project_environment}` from a `locals` block in the env's `main.tf`:

```hcl
locals {
  env_suffix = "-${var.project_environment}"
}

module "document_lambda" {
  document_lambda_function_name = "${var.document_lambda_function_name}${local.env_suffix}"
  # ...same pattern for every *_name input
}
```

This keeps dev and prod able to coexist in the same AWS account without colliding on globally-unique names (S3 buckets, IAM roles, IAM managed policies, Lambda functions, DynamoDB tables, SNS topics). `terraform.tfvars` holds **base** names; the env appends the suffix. Modules don't know about envs and don't take a `project_env` input — they receive a fully-formed name string.

IAM `Sid` values inside policy documents are kept as static literals (`DocumentLambdaRole`, `S3AccessPolicy`, etc.) — AWS requires Sids to be alphanumeric, so they can't carry the `-dev` hyphen. Sids are document-local, so reusing the same label across envs is harmless.

## Common Commands

Run from inside an env directory (e.g., `cd infrastructure/envs/dev`):

```bash
terraform init                # download providers/modules, configure backend
terraform plan                # preview changes
terraform apply               # apply changes
terraform destroy             # tear everything down
terraform validate            # syntax check
terraform fmt -recursive      # format
```

## State Management

Remote state lives in S3 (`aci-capstone1-remote-state`, `us-east-1`) with native S3 locking (`use_lockfile = true`). State key:

- `envs/dev/terraform.tfstate`

Configured in `envs/dev/backend.tf`. Do **not** commit local `.tfstate` files — `.gitignore` already excludes them. Note: `encrypt = true` is currently commented out.

## Variables

`terraform.tfvars` is **gitignored** because it contains environment-specific values. Variables flow in two layers (sub-module ⇄ env). To add a new input to an existing sub-module:

1. Declare it in `infrastructure/modules/<sub>/variables.tf` with `type` + validation
2. Use it in the sub-module's `.tf` resources
3. Add a pass-through declaration in `envs/dev/variables.tf`
4. Set the value in `envs/dev/terraform.tfvars`
5. Forward it inside the `module "<sub>" { ... }` block in `envs/dev/main.tf`

**Shortcut:** if a value is identical across envs, hardcode it directly in the env's `module` call (skip steps 3–4) or give it a `default` in the sub-module's `variables.tf`.

To add a brand-new sub-module: create `infrastructure/modules/<name>/{main.tf,variables.tf,outputs.tf,README.md}`, then add `module "<name>" { source = "../../modules/<name>" ... }` to `envs/dev/main.tf`.

## Cross-module values

Sub-modules are isolated scopes — `modules/lambda/` cannot directly reference `module.document_s3_bucket` from `modules/s3/`. Shared values must flow through the env:

```
modules/s3/outputs.tf       → exposes bucket ARN as `document_bucket_arn`
envs/dev/main.tf            → reads it, passes into the lambda module call
modules/lambda/variables.tf → receives it as var.document_s3_bucket_arn
modules/lambda/*.tf         → uses var.document_s3_bucket_arn
```

This is how the Lambda IAM policy gets the bucket ARN today, and the same pattern flows `document_bucket_name` from `modules/s3/outputs.tf` into the lambda module for the `aws_s3_bucket_notification`. The DynamoDB table **name** and **ARN** flow the same way — name becomes the `TABLE` runtime env variable (on the document, write-to-dynamo, and compare-faces Lambdas); ARN scopes the inline IAM policy. The SNS topic **ARN** and **name** also flow from `modules/sns/outputs.tf` into the lambda module — ARN scopes the inline IAM policy and should be the `TOPIC` runtime env variable (on the document, submit-license, and compare-faces Lambdas). The env's `main.tf` also declares `data "aws_caller_identity"` and `data "aws_region"` and passes `current_account_id` / `current_region` into the lambda module so its CloudWatch IAM policy can build region/account-scoped ARNs without hardcoding.

## Default Tags

Every resource inherits these tags via the provider's `default_tags` block:

| Tag          | Value                       |
|--------------|-----------------------------|
| `Project`    | `var.project_name`          |
| `Environment`| `var.project_environment`   |
| `Owner`      | `var.project_owner`         |
| `ManagedBy`  | `Terraform`                 |

## Pinned Module Versions

| Module                                     | Version    |
|--------------------------------------------|------------|
| `terraform-aws-modules/s3-bucket/aws`      | `5.12.0`   |
| `terraform-aws-modules/dynamodb-table/aws` | `5.5.0`    |
| `terraform-aws-modules/sns/aws`            | `7.1.0`    |
| `hashicorp/aws` provider                   | `~> 6.4` (locked at 6.52.0) |

## Notes

- Toggling `customer_metadata_table_autoscaling_enabled` recreates the DynamoDB table — use `terraform state mv` to preserve data (see `modules/dynamodb/README.md`).
- The SNS email subscription requires manual confirmation from the inbox before notifications will deliver.
