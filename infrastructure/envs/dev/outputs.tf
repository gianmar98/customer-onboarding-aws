output "document_bucket_name" {
  description = "Name of the document S3 bucket"
  value       = module.document_backend.document_bucket_name
}

output "document_bucket_arn" {
  description = "ARN of the document S3 bucket"
  value       = module.document_backend.document_bucket_arn
}

output "customer_metadata_table_name" {
  description = "Name of the CustomerMetadata DynamoDB table"
  value       = module.document_backend.customer_metadata_table_name
}

output "customer_metadata_table_arn" {
  description = "ARN of the CustomerMetadata DynamoDB table"
  value       = module.document_backend.customer_metadata_table_arn
}

output "document_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.document_backend.document_lambda_role_arn
}

output "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = module.document_backend.document_lambda_role_name
}

output "sns_topic_arn" {
  description = "ARN of the application notifications SNS topic"
  value       = module.document_backend.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the application notifications SNS topic"
  value       = module.document_backend.sns_topic_name
}