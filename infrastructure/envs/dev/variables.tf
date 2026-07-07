# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# Project-wide ----------------------------------------------------------------------
variable "project_region" {
  description = "AWS region the project deploys to"
  type        = string
}

variable "project_environment" {
  description = "Environment name (e.g., dev, prod) — used in default_tags"
  type        = string
}

variable "project_name" {
  description = "Project name — used in default_tags"
  type        = string
}

variable "project_owner" {
  description = "Owner — used in default_tags"
  type        = string
}

# S3 ---------------------------------------------------------------------------------
variable "document_s3_bucket_name" {
  description = "Name of the document S3 bucket"
  type        = string
}


# Lambda -------------------------------------------------------------------------
variable "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "document_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}

variable "lambda_cloudwatch_logs_policy_name" {
  description = "Name of the CloudWatch Logs Policy"
  type        = string
}

variable "document_lambda_function_name" {
  description = "Name of the document Lambda function"
  type        = string
}

variable "document_lambda_function_timeout" {
  description = "The max mount of time function should run for"
  type        = number
}

variable "lambda_rekognition_face_comparison_policy_name" {
  description = "This will be the name of the managed policy so lambda can compare faces"
  type        = string
}

variable "lambda_textract_analyze_id_policy_name" {
  description = "This will be the name of the managed policy so Textract can analyze ID"
  type        = string
}

variable "validate_lambda_function_name" {
  description = "This is the name for my Lambda function to validate my documents"
  type        = string
}

variable "validate_lambda_role_name" {
  description = "This is the name of the Role of my validation lambda function"
  type        = string
}

variable "validation_lambda_cloudwatch_logs_policy_name" {
  description = "Name of the CloudWatch Logs Policy for my Validation Lambda"
  type        = string
}

variable "submit_license_lambda_function_name" {
  description = "This is the name for my Lambda function to validate my documents"
  type        = string
}

variable "submit_license_lambda_role_name" {
  description = "This is the name of the Role of my validation lambda function"
  type        = string
}

variable "submit_license_lambda_cloudwatch_logs_policy_name" {
  description = "Name of the CloudWatch Logs Policy for my Validation Lambda"
  type        = string
}

variable "sqs_submit_license_policy_name" {
  description = "This is the name of the policy that allows SQS to invoke lambda"
  type        = string
}

variable "submit_license_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}

variable "unzip_lambda_function_name" {
  description = "Name of the lambda function to unzip the file and extract the app_uuid"
  type        = string
}

variable "unzip_lambda_function_role_name" {
  description = "Name of the role being assumed by the Lambda function that will unzip the license file"
  type        = string
}

variable "unzip_license_lambda_cloudwatch_logs_policy_name" {
  description = "Name of the policy so unzip license lambda can send logs to cloudwatch"
  type        = string
}


# DynamoDB ---------------------------------------------------------------------------
variable "customer_metadata_dynamo_db_table_name" {
  description = "Name of the customer metadata DynamoDB table"
  type        = string
}

variable "customer_metadata_table_hash_partition_key" {
  description = "Hash/Partition key of the customer metadata table"
  type        = string
}

variable "customer_metadata_table_class" {
  description = "Storage class for the customer metadata DynamoDB table"
  type        = string
  default     = "STANDARD"
}

variable "customer_metadata_table_RCU" {
  description = "Read Capacity Units"
  type        = number
}

variable "customer_metadata_table_WCU" {
  description = "Write Capacity Units"
  type        = number
}

variable "customer_metadata_table_autoscaling_enabled" {
  description = "Enable autoscaling on the customer metadata table"
  type        = bool
}

variable "customer_metadata_table_min_RWcapacity" {
  description = "Minimum autoscaling capacity"
  type        = number
}

variable "customer_metadata_table_max_RWcapacity" {
  description = "Maximum autoscaling capacity"
  type        = number
}

variable "customer_metadata_table_target_scaling_val" {
  description = "Target % of provisioned capacity to trigger autoscaling"
  type        = number
}

# SNS --------------------------------------------------------------------------------
variable "app_notification_sns_name" {
  description = "Name of the application notifications SNS topic"
  type        = string
}

variable "app_notification_kms_key" {
  description = "KMS master key id/alias used to encrypt the SNS topic"
  type        = string
}

variable "app_notification_email_endpoint" {
  description = "Email subscribed to the SNS topic"
  type        = string
}

# API GATEWAY ----
variable "validate_api_gw_name" {
  description = "This is the name of the API GW that will trigger the validation Lambda"
  type        = string
}

# SQS ------------
variable "sqs_queue_name" {
  description = "This is the name of the SQS queue"
  type        = string
}

variable "sqs_dlq_name" {
  description = "This is the name of the SQS DLQ"
  type        = string
}

