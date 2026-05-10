# S3 Module

Provisions the document storage S3 bucket plus a TLS-only bucket policy.

## Resources

- `module.document_s3_bucket` — `terraform-aws-modules/s3-bucket/aws` v5.12.0
  - AES256 server-side encryption (default)
  - Public access blocked (the upstream module's default)
- `aws_s3_bucket_policy.document_bucket_tls_only` — denies any non-HTTPS request (`aws:SecureTransport = false`)

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_s3_bucket_name` | `string` | Name of the document S3 bucket |

## Outputs

| Name | Description |
|---|---|
| `document_bucket_name` | Name (ID) of the document S3 bucket |
| `document_bucket_arn` | ARN of the document S3 bucket — consumed by the lambda module via the env |
| `document_bucket_regional_domain_name` | Regional domain name of the bucket |

## Notes

- Bucket names are globally unique across AWS — pick something distinctive in `terraform.tfvars`.
- For the AWS S3 bucket module, `s3_bucket_id` equals the bucket name.