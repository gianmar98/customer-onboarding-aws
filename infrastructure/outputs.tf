output "document_bucket_name" {
  value       = module.document-s3-bucket.s3_bucket_id
  description = "The name of the document S3 bucket"
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.CustomerMetadataTable-dynamodb-table.dynamodb_table_arn
}