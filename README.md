# ACI Capstone 1

AWS infrastructure for a serverless document-handling backend, provisioned entirely with Terraform.

## Stack

- **S3** — document storage bucket (TLS-only, public access blocked, AES256 SSE)
- **DynamoDB** — `CustomerMetadataTable` (provisioned capacity with optional autoscaling, partition key `APP_UUID`)
- **Lambda IAM** — execution role + inline policy for S3 R/W/Delete and CloudWatch Logs (Lambda function itself not yet provisioned)
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
│   ├── modules/                  # Shared module — all real Terraform
│   │   ├── main.tf                 # required_providers (no provider block)
│   │   ├── variables.tf            # module inputs + validation
│   │   ├── outputs.tf              # exported ARNs / names
│   │   ├── s3.tf                   # document bucket + TLS-only policy
│   │   ├── dynamodb.tf             # customer metadata table
│   │   ├── document_lambda.tf      # Lambda IAM role + policy
│   │   └── sns.tf                  # notifications topic + email sub
│   └── envs/
│       └── dev/                  # provider config + module call + dev tfvars
│           ├── backend.tf          # state at envs/dev/terraform.tfstate
│           ├── main.tf             # module "document_backend" { source = "../../modules" }
│           ├── variables.tf        # pass-through declarations
│           ├── outputs.tf
│           └── terraform.tfvars    # gitignored
└── frontend/                  # (placeholder — not yet implemented)
```

Only `dev` exists today. A `prod` env can be added by copying the `dev/` directory, swapping the backend `key`, and supplying its own `terraform.tfvars`.

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

Remote state lives in S3 (`aci-capstone1-remote-state`, `us-east-1`) with native S3 locking (`use_lockfile = true`). Each env writes to its own state key:

- `envs/dev/terraform.tfstate`

Configured in each env's `backend.tf`. Do **not** commit local `.tfstate` files — `.gitignore` already excludes them. Note: `encrypt = true` is currently commented out in `dev/backend.tf`.

## Variables

`terraform.tfvars` is **gitignored** because it contains environment-specific values. Variables flow through two layers (module → env wrapper). To add a new variable:

1. Declare it in `modules/variables.tf` with `type` + validation
2. Add a pass-through declaration in `envs/dev/variables.tf`
3. Set the value in `envs/dev/terraform.tfvars`
4. Forward it in `envs/dev/main.tf` inside the `module "document_backend"` block
5. Expose any ARNs/IDs via `modules/outputs.tf` and `envs/dev/outputs.tf`

**Shortcut:** if a value is identical across envs, hardcode it in the module call or give it a `default` in `modules/variables.tf` and skip the env-level plumbing.

## Default Tags

Every resource inherits the following tags via the provider's `default_tags` block:

| Tag | Value |
|---|---|
| `Project` | `var.project_name` |
| `Environment` | `var.project_environment` |
| `Owner` | `var.project_owner` |
| `ManagedBy` | `Terraform` |

## Pinned Module Versions

| Module | Version |
|---|---|
| `terraform-aws-modules/s3-bucket/aws` | `5.12.0` |
| `terraform-aws-modules/dynamodb-table/aws` | `5.5.0` |
| `terraform-aws-modules/sns/aws` | `7.1.0` |
| `hashicorp/aws` provider | `~> 6.0` |

## Notes

- Toggling `customer_metadata_table_autoscaling_enabled` recreates the DynamoDB table — use `terraform state mv` to preserve data.
- The SNS email subscription requires manual confirmation from the inbox before notifications will deliver.