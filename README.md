# ACI Capstone 1

AWS infrastructure for a serverless document-handling backend, provisioned entirely with Terraform.

## Stack

All resource names are stamped with `-${project_environment}` (e.g. `-dev`, `-prod`) at the env layer — see **Env-suffix naming** below. Each service below is provisioned by its own Terraform sub-module; see that module's `README.md` for resource-level detail, inputs/outputs, and gotchas.

- **S3** (`infrastructure/modules/s3/`) — document storage bucket, TLS-only.
- **DynamoDB** (`infrastructure/modules/dynamodb/`) — `CustomerMetadataTable`, keyed by `APP_UUID`.
- **Lambda** (`infrastructure/modules/lambda/`) — six functions forming two pipelines: a monolithic document-processing Lambda (S3-triggered) plus a validation/submit-license pair (API Gateway + SQS), and a separate unzip → write-to-dynamo → compare-faces pipeline invoked externally (e.g. by Step Functions, not yet built). Runs face-match (Rekognition) and ID-field extraction (Textract) checks, records results in DynamoDB, and notifies via SNS.
- **SNS** (`infrastructure/modules/sns/`) — `ApplicationNotifications` topic with email subscription.
- **API Gateway** (`infrastructure/modules/apiGateway/`) — `ValidateLicenseApi`, HTTP API exposing `POST /license` (internal mock validator, not a browser-facing API).
- **SQS** (`infrastructure/modules/sqs/`) — `LicenseQueue` + dead-letter queue, connecting the document Lambda to the submit-license Lambda.

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
│   │   │   ├── outputs.tf
│   │   │   └── README.md
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
└── frontend/                # Next.js frontend — see frontend/CLAUDE.md and frontend_tutorial.md
```

The structure is **per-resource sub-modules composed by the env**. Only `dev` exists today; a `prod` env can be added later by copying `dev/`, swapping the backend `key`, and setting `project_environment = "prod"` in the new `terraform.tfvars` — the base names stay identical and the env-suffix pattern (see below) makes every resource land as `*-prod` automatically.

## Env-suffix naming

Every resource name is stamped with `-${var.project_environment}` (e.g. `-dev`, `-prod`) at the env layer, so multiple envs can coexist in one AWS account without colliding on globally-unique names. See `CLAUDE.md`'s "Env-suffix naming pattern" for the mechanism and exceptions.

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

Sub-modules are isolated scopes — shared values (bucket ARN, table ARN, topic ARN, etc.) flow through the env's `main.tf`, which reads each module's `outputs.tf` and passes values into the next module's inputs. See `modules/lambda/README.md`'s "Cross-module dependencies" for the full wiring diagram (it's the biggest consumer of cross-module values).

## Default Tags

Every resource inherits these tags via the provider's `default_tags` block:

| Tag          | Value                       |
|--------------|-----------------------------|
| `Project`    | `var.project_name`          |
| `Environment`| `var.project_environment`   |
| `Owner`      | `var.project_owner`         |
| `ManagedBy`  | `Terraform`                 |

Pinned module versions and Terraform-specific notes/gotchas live in `CLAUDE.md` and each module's own `README.md`.
