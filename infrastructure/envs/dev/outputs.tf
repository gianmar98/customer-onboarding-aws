# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

output "document_bucket_name" {
  description = "Name of the document S3 bucket"
  value       = module.document_s3_bucket.document_bucket_name
}

output "document_bucket_arn" {
  description = "ARN of the document S3 bucket"
  value       = module.document_s3_bucket.document_bucket_arn
}

output "customer_metadata_table_name" {
  description = "Name of the CustomerMetadata DynamoDB table"
  value       = module.customer_metadata_dynamo_db_table.customer_metadata_table_name
}

output "customer_metadata_table_arn" {
  description = "ARN of the CustomerMetadata DynamoDB table"
  value       = module.customer_metadata_dynamo_db_table.customer_metadata_table_arn
}

output "document_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.document_lambda.document_lambda_role_arn
}

output "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = module.document_lambda.document_lambda_role_name
}

output "sns_topic_arn" {
  description = "ARN of the application notifications SNS topic"
  value       = module.app_notification_sns.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the application notifications SNS topic"
  value       = module.app_notification_sns.sns_topic_name
}

output "license_validation_post_api_invoke_url" {
  description = "Invoke URL for POST /license"
  value       = module.api_gateway.license_validation_invoke_url
}

output "validate_sqs_queue_arn" {
  description = "ARN of the SQS license validate"
  value       = module.sqs.sqs_license_queue_arn
}

output "cognito_user_pool_name" {
  description = "Name of the Cognito user pool"
  value       = module.congito.cognito_user_pool_name
}

output "cognito_user_pool_client_name" {
  description = "Name of the Cognito user pool Client"
  value       = module.congito.cognito_user_pool_client_name
}