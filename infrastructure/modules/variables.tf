# S3 ---------------------------------------------------------------------------------
variable "document_s3_bucket_name" {
  description = "Name of the document S3 bucket"
  type        = string
}

# variable "encryption_enabled_backend" {
#   description = "Enable encryption on s3 bucket"
#   type = bool
# }

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
  description = "Storage class for the customer metadata DynamoDB table. Allowed: STANDARD, STANDARD_INFREQUENT_ACCESS."
  type        = string
  # default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.customer_metadata_table_class)
    error_message = "customer_metadata_table_class must be one of: STANDARD, STANDARD_INFREQUENT_ACCESS."
  }
}

variable "customer_metadata_table_RCU" {
  description = "Read Capacity Units for the customer metadata table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_RCU >= 2
    error_message = "RCU must be at least 2"
  }
}

variable "customer_metadata_table_WCU" {
  description = "Write Capacity Units for the customer metadata table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_WCU >= 2
    error_message = "WCU must be at least 2"
  }
}

variable "customer_metadata_table_autoscaling_enabled" {
  description = "Enable autoscaling on the customer metadata table"
  type        = bool
}

variable "customer_metadata_table_min_RWcapacity" {
  description = "Minimum autoscaling capacity for the customer metadata table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_min_RWcapacity >= 2
    error_message = "Min R/W capacity must be at least 2"
  }
}

variable "customer_metadata_table_max_RWcapacity" {
  description = "Maximum autoscaling capacity for the customer metadata table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_max_RWcapacity <= 20
    error_message = "Max R/W capacity must be at most 20"
  }
}

variable "customer_metadata_table_target_scaling_val" {
  description = "Target % of provisioned capacity to trigger autoscaling"
  type        = number
  validation {
    condition     = var.customer_metadata_table_target_scaling_val >= 1 && var.customer_metadata_table_target_scaling_val <= 100
    error_message = "Target scaling value must be between 1 and 100."
  }
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
  description = "Email address subscribed to the SNS topic (requires manual confirmation)"
  type        = string
}