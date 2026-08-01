# S3 Module

Provisions the document storage S3 bucket, its KMS customer managed key, and a TLS-only bucket policy.

## Resources

- `module.document_s3_bucket` — `terraform-aws-modules/s3-bucket/aws` v5.12.0
  - **SSE-KMS** with the CMK below, `bucket_key_enabled = true`
  - Public access blocked (the upstream module's default)
  - `force_destroy = true` — `terraform destroy` will empty the bucket before deleting it, so it won't fail with `BucketNotEmpty`
  - **Two lifecycle rules** (`expire-uploaded-documents`, `expire-extracted-documents`) expiring `zipped/` and `unzipped/` objects after `var.document_retention_days` (default 30), plus `abort_incomplete_multipart_upload_days = 7` on both. The bucket holds PII — selfies and driver's licenses — so documents aren't retained indefinitely.
  - **Versioning is deliberately off.** A resubmission reuses the same `app_uuid`, so the newest upload *is* the correct data and there's no earlier version worth recovering. Enabling it is also irreversible (it can only be suspended, never removed).
- `aws_kms_key.document_key` / `aws_kms_alias.document_key` — customer managed key encrypting the bucket. `enable_key_rotation = true`, `deletion_window_in_days = 30`, and `lifecycle { prevent_destroy = true }`. No explicit key policy, so the default (account root gets `kms:*`) applies and the Lambda roles' IAM policies are what actually grant access.
- `aws_s3_bucket_policy.document_bucket_tls_only` — denies any non-HTTPS request (`aws:SecureTransport = false`)
- `aws_s3_object.zipped_prefix` — empty `zipped/` placeholder object so the prefix exists in the console before the first upload. Uploads under that prefix are what start the pipeline (via the EventBridge rule in `modules/stepFunction/`).

## Inputs

| Name | Type | Description |
|---|---|---|
| `document_s3_bucket_name` | `string` | Name of the document S3 bucket |
| `document_retention_days` | `number` | Days after upload that `zipped/`/`unzipped/` objects expire. Set per-env in `envs/dev/terraform.tfvars`; falls back to `30` if the caller omits it. Validated `> 0`. |

## Outputs

| Name | Description |
|---|---|
| `document_bucket_name` | Name (ID) of the document S3 bucket |
| `document_bucket_arn` | ARN of the document S3 bucket — consumed by the lambda module via the env |
| `document_bucket_regional_domain_name` | Regional domain name of the bucket |
| `document_bucket_id` | Bucket ID — consumed by the stepFunction module, which attaches the bucket's EventBridge notification |
| `document_kms_key_arn` | ARN of the CMK — consumed by the lambda module via the env, where it scopes the `KMSAccessPolicy` statement on the four pipeline roles |

## Notes

- Bucket names are globally unique across AWS — pick something distinctive in `terraform.tfvars`.
- For the AWS S3 bucket module, `s3_bucket_id` equals the bucket name — `document_bucket_id` and `document_bucket_name` are the same value under two names.
- **Objects here are deleted after 30 days by default.** That's the point of the lifecycle rules, but it means a demo zip uploaded more than a month ago will be gone. Raise `document_retention_days` if you need sample data to persist.
- **This module does not define the bucket's notification config.** `modules/stepFunction/` owns it (`eventbridge = true`), and a bucket accepts only one — don't add a second here.
- **`s3:GetObject` is no longer sufficient to read an object.** Once the bucket is SSE-KMS, any role reading objects also needs `kms:Decrypt` on the CMK, and any role writing them needs `kms:GenerateDataKey`. Missing the KMS half surfaces as `AccessDenied` on the S3 call, which reads like an S3 permissions problem and isn't. The four pipeline roles are granted in `modules/lambda/lambda_policies.tf`.
- **Rekognition and Textract read these objects with the *calling Lambda's* credentials**, not a service principal of their own. That's why the CMK needs no `rekognition.amazonaws.com` / `textract.amazonaws.com` entry in its key policy — `kms:Decrypt` on the compare-faces and compare-details roles is what makes those calls work.
- **Changing default encryption only affects new writes.** Objects written before this change are still SSE-S3 and still readable; nothing is re-encrypted.
- **Deleting the CMK permanently destroys every object still encrypted with it.** `prevent_destroy` makes `terraform destroy` fail on the key rather than schedule it — remove that block deliberately, and expect the alias name to stay reserved for the 30-day window afterward.
- Rotation is invisible to this project: it adds new key material inside the same key (same ID, ARN, and alias) and retains old material, so previously written objects keep decrypting. Cost is $1/mo for the key plus $1/mo each for the first two rotations, capped there.