# S3 Module

Provisions the document storage S3 bucket plus a TLS-only bucket policy.

## Resources

- `module.document_s3_bucket` — `terraform-aws-modules/s3-bucket/aws` v5.12.0
  - AES256 server-side encryption (default)
  - Public access blocked (the upstream module's default)
  - `force_destroy = true` — `terraform destroy` will empty the bucket before deleting it, so it won't fail with `BucketNotEmpty`
- `aws_s3_bucket_policy.document_bucket_tls_only` — denies any non-HTTPS request (`aws:SecureTransport = false`)
- `aws_s3_object.zipped_prefix` — empty `zipped/` placeholder object so the prefix exists in the console before the first upload. Uploads under that prefix are what start the pipeline (via the EventBridge rule in `modules/stepFunction/`).

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
| `document_bucket_id` | Bucket ID — consumed by the stepFunction module, which attaches the bucket's EventBridge notification |

## Notes

- Bucket names are globally unique across AWS — pick something distinctive in `terraform.tfvars`.
- For the AWS S3 bucket module, `s3_bucket_id` equals the bucket name — `document_bucket_id` and `document_bucket_name` are the same value under two names.
- **This module does not define the bucket's notification config.** `modules/stepFunction/` owns it (`eventbridge = true`), and a bucket accepts only one — don't add a second here.