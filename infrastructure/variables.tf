// CONTAINER FOR ALL VARIABLES

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

variable "customer_metadata_table_hashPartition_key" {
  description = "Hash/Partition Key of my customer metadata table"
  type        = string
}

variable "customer_metadata_table_class" {
  description = "Class for customer metadata table"
  type        = string
  validation {
    condition     = var.customer_metadata_table_class == "STANDARD"
    error_message = "Metadata class must be 'STANDARD' all caps"
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