# Lambda IAM Module

Provisions the IAM role and inline policy intended to be assumed by the document-handling Lambda function. The Lambda function itself is **not** provisioned here yet.

## Resources

- `aws_iam_role.document_lambda` — assume-role policy trusts `lambda.amazonaws.com`
- `aws_iam_role_policy.document_lambda` — inline policy granting:
  - `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `${document_s3_bucket_arn}/*`
  - `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on `arn:aws:logs:*:*:*`

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_lambda_role_name` | `string` | Name for the IAM role |
| `document_lambda_policy_name` | `string` | Name for the inline policy |
| `document_s3_bucket_arn` | `string` | ARN of the bucket the Lambda is allowed to read/write/delete from. Wired from `module.document_s3_bucket.document_bucket_arn` in `envs/dev/main.tf`. |

## Outputs

| Name | Description |
|---|---|
| `document_lambda_role_arn` | ARN of the Lambda execution role |
| `document_lambda_role_name` | Name of the Lambda execution role |

## Cross-module dependency

This module needs the document bucket's ARN. Sub-modules can't reference each other directly, so the value flows through the env:

```
modules/s3/outputs.tf      → output "document_bucket_arn"
envs/dev/main.tf           → document_s3_bucket_arn = module.document_s3_bucket.document_bucket_arn
modules/lambda/variables.tf → var.document_s3_bucket_arn
```