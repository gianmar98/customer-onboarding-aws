# ACI Capstone 1

AWS infrastructure for a serverless document-handling backend, provisioned entirely with Terraform.

## Stack

- **S3** — document storage bucket (TLS-only, public access blocked, AES256 SSE)
- **DynamoDB** — `CustomerMetadataTable` (provisioned capacity with optional autoscaling, partition key `APP_UUID`)
- **Lambda** — `DocumentLambdaFunction` (Python 3.13, 20 s timeout) packaged from `modules/lambda/src/` via `archive_file`. Triggered by `s3:ObjectCreated:Put` events under the `zipped/` prefix of the document bucket. Execution role uses an **inline** policy (S3 `Get`/`Put`/`Delete`, DynamoDB `PutItem`/`UpdateItem`, SNS `Publish`) plus a separate **customer-managed** policy for least-privilege CloudWatch Logs access. Function owns its own `aws_cloudwatch_log_group` (`/aws/lambda/DocumentLambdaFunction`, 14-day retention) wired via `logging_config`.
- **SNS** — `ApplicationNotifications` topic with email subscription, KMS-encrypted

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
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── dynamodb/          # CustomerMetadataTable
│   │   │   ├── dynamodb.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── lambda/            # IAM (role + inline + managed), Lambda function, log group, S3 trigger
│   │   │   ├── lambda_policies.tf          # role, inline policy, managed CW policy + attachment, log group
│   │   │   ├── document_lambda_function.tf # function, archive_file, S3 notification, invoke permission
│   │   │   ├── src/                        # Python handler source (s3_upload.py)
│   │   │   ├── build/                      # archive_file zip output (gitignored)
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   └── sns/               # ApplicationNotifications topic + email sub
│   │       ├── sns.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   └── envs/
│       └── dev/
│           ├── backend.tf       # state at envs/dev/terraform.tfstate
│           ├── main.tf          # composes all 4 sub-modules
│           ├── variables.tf     # pass-through declarations
│           ├── outputs.tf       # forwards each sub-module's outputs
│           └── terraform.tfvars # gitignored
└── frontend/                # (placeholder — not yet implemented)
```

The structure is **per-resource sub-modules composed by the env**. Only `dev` exists today; a `prod` env can be added later by copying `dev/`, swapping the backend `key`, and supplying its own `terraform.tfvars`.

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

This is how the Lambda IAM policy gets the bucket ARN today, and the same pattern flows `document_bucket_name` from `modules/s3/outputs.tf` into the lambda module for the `aws_s3_bucket_notification`. The env's `main.tf` also declares `data "aws_caller_identity"` and `data "aws_region"` and passes `current_account_id` / `current_region` into the lambda module so its CloudWatch IAM policy can build region/account-scoped ARNs without hardcoding.

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
| `hashicorp/aws` provider                   | `~> 6.0`   |

## Notes

- Toggling `customer_metadata_table_autoscaling_enabled` recreates the DynamoDB table — use `terraform state mv` to preserve data (see `modules/dynamodb/README.md`).
- The SNS email subscription requires manual confirmation from the inbox before notifications will deliver.
