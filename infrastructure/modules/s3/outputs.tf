# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# S3 ---------------------------------------------------------------------------------
output "document_bucket_name" {
  description = "Name (ID) of the document S3 bucket"
  value       = module.document_s3_bucket.s3_bucket_id
}

output "document_bucket_arn" {
  description = "ARN of the document S3 bucket"
  value       = module.document_s3_bucket.s3_bucket_arn
}

output "document_bucket_regional_domain_name" {
  description = "Regional domain name of the document S3 bucket"
  value       = module.document_s3_bucket.s3_bucket_bucket_regional_domain_name
}

