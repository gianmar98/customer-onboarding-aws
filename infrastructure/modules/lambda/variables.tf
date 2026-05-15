# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# Lambda IAM -------------------------------------------------------------------------
variable "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "document_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}


variable "lambda_function_name" {
  description = "This is the name of the Lambda that will interact"
  type = string
}

variable "current_region" {
  description = "Current project region of deployment"
  type = string
}

variable "current_account_id" {
  description = "Current account ID"
  type = string
}

variable "lambda_cloudwatch_logs_policy_name" {
  description = "Name of the CloudWatch Logs Policy"
  type = string
}
#--------------------------

variable "document_s3_bucket_arn" {
  description = "ARN of the document S3 bucket Lambda needs to access to"
  type = string
}

variable "dynamodb_metadata_table_arn" {
  description = "ARN of the dynamoDB metadata table that Lambda needs to access to"
  type = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic that Lambda needs to access"
  type = string
}
