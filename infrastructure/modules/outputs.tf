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

# DynamoDB ---------------------------------------------------------------------------
output "customer_metadata_table_name" {
  description = "Name of the CustomerMetadata DynamoDB table"
  value       = module.customer_metadata_table.dynamodb_table_id
}

output "customer_metadata_table_arn" {
  description = "ARN of the CustomerMetadata DynamoDB table"
  value       = module.customer_metadata_table.dynamodb_table_arn
}

# Lambda IAM -------------------------------------------------------------------------
output "document_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.document_lambda.arn
}

output "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.document_lambda.name
}

# SNS --------------------------------------------------------------------------------
output "sns_topic_arn" {
  description = "ARN of the application notifications SNS topic"
  value       = module.app_notification_sns.topic_arn
}

output "sns_topic_name" {
  description = "Name of the application notifications SNS topic"
  value       = module.app_notification_sns.topic_name
}