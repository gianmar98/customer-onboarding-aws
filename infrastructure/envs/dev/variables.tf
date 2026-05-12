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


# Lambda IAM -------------------------------------------------------------------------
variable "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}

variable "document_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
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