# ACI Capstone 1

AWS infrastructure for a serverless document-handling backend, provisioned entirely with Terraform.

## Stack

- **S3** — document storage bucket (TLS-only, public access blocked, AES256 SSE)
- **DynamoDB** — `CustomerMetadataTable` (provisioned capacity with autoscaling, partition key `APP_UUID`)
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
├── infrastructure/      # All Terraform code
│   ├── main.tf            # provider + default tags
│   ├── backend.tf         # S3 remote state config
│   ├── variables.tf       # variable declarations
│   ├── terraform.tfvars   # variable values (gitignored)
│   ├── outputs.tf         # exported ARNs / names
│   ├── s3.tf              # document bucket + TLS-only policy
│   ├── DynamoDB.tf        # customer metadata table
│   ├── documentLambda.tf  # Lambda IAM role + policy
│   └── sns.tf             # notifications topic + email sub
└── frontend/            # (placeholder — not yet implemented)
```

## Common Commands

Run from the `infrastructure/` directory:

```bash
terraform init                # download providers/modules, configure backend
terraform plan                # preview changes
terraform apply               # apply changes
terraform destroy             # tear everything down
terraform validate            # syntax check
terraform fmt -recursive      # format
```

## State Management

Remote state lives in S3 (`aci-capstone1-remote-state`, `us-east-1`) with native S3 locking (`use_lockfile = true`). Configured in `backend.tf`. Do **not** commit local `.tfstate` files — `.gitignore` already excludes them.

## Variables

`terraform.tfvars` is **gitignored** because it contains environment-specific values. New variables follow the pattern:

1. Declare in `variables.tf` (with `description`, `type`, and validation where useful)
2. Set the value in `terraform.tfvars`
3. Expose any ARNs/IDs via `outputs.tf`

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

- Toggling `customer_metadata_table_autoscaling_enabled` recreates the DynamoDB table — use `terraform state mv` to preserve data (see comment in `terraform.tfvars`).
- The SNS email subscription requires manual confirmation from the inbox before notifications will deliver.