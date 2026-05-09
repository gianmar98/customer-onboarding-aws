// CONTAINER FOR ALL VARIABLES

# PROJECT MAIN ---------------------------------------------------------------------------------
variable "project_region" {
  description = "Region the project will be created on"
  type        = string
}

variable "project_environment" {
  description = "Environment name of the project (ex: dev)"
  type        = string
}

variable "project_name" {
  description = "Name of the project so all resources get tagged"
  type        = string
}

variable "project_owner" {
  description = "Name of project owner so all resources get tagged"
  type        = string
}
#-------------------------------------------------------------------------------------

# S3 ---------------------------------------------------------------------------------
variable "document_s3_bucket_name" {
  description = "This is the name of the document S3 bucket for the project"
  type        = string
}
#-------------------------------------------------------------------------------------

# Lambda ---------------------------------------------------------------------------------
variable "document_lambda_role_name" {
  description = "Role of Lambda to r/w/delete with policy attached"
  type        = string
}
variable "document_lambda_policy_name" {
  description = "Policy to be attached to lambda function that it can read, write, and delete objects from the document bucket"
  type        = string
}

#--------------------------------------------------------------------------------------

# DynamoDB ---------------------------------------------------------------------------------
variable "customer_metadata_dynamo_db_table_name" {
  description = "Name of my Customer Metadata Table"
  type        = string
}

variable "customer_metadata_table_hash_partition_key" {
  description = "Hash/Partition Key of my customer metadata table"
  type        = string
}

variable "customer_metadata_table_class" {
  description = "Storage class for the customer metadata DynamoDB table. Allowed: STANDARD, STANDARD_INFREQUENT_ACCESS."
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.customer_metadata_table_class)
    error_message = "customer_metadata_table_class must be one of: STANDARD, STANDARD_INFREQUENT_ACCESS."
  }
}

variable "customer_metadata_table_RCU" {
  description = "Read Capacity Units for customer metadata dynamoDB table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_RCU >= 2
    error_message = "RCU must be at least 2"
  }
}

variable "customer_metadata_table_WCU" {
  description = "Write Capacity Units for customer metadata dynamoDB table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_WCU >= 2
    error_message = "WCU must be at least 2"
  }
}

variable "customer_metadata_table_autoscaling_enabled" {
  description = "Bool to enable table auto scaling or not"
  type        = bool
}

variable "customer_metadata_table_min_RWcapacity" {
  description = "Minimum capacity of autoscaling for customer metadata table"
  type        = number
  validation {
    condition     = var.customer_metadata_table_min_RWcapacity >= 2
    error_message = "Min R/W capacity must be at least 2"
  }
}

variable "customer_metadata_table_max_RWcapacity" {
  description = "Maximum capacity of autoscaling for customer metadata table"
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
# ---------------------------------------------------------------------------------



# SNS Topic ---------------------------------------------------------------------------------

variable "app_notification_sns_name" {
  description = "Name of Application Notification SNS Topic"
  type        = string
}

variable "app_notification_kms_key" {
  description = "Master key (default) for SNS from KMS"
  type        = string
}

variable "app_notification_email_endpoint" {
  description = "Email endpoint to send subscription for SNS topic"
  type        = string
}



# ---------------------------------------------------------------------------------
