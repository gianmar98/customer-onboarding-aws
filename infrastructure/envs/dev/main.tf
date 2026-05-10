terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.project_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.project_environment
      Owner       = var.project_owner
      ManagedBy   = "Terraform"
    }
  }
}

module "document_s3_bucket" {
  source                  = "../../modules/s3"
  document_s3_bucket_name = var.document_s3_bucket_name
}

module "customer_metadata_dynamo_db_table" {
  source                                      = "../../modules/dynamodb"
  customer_metadata_dynamo_db_table_name      = var.customer_metadata_dynamo_db_table_name
  customer_metadata_table_class               = var.customer_metadata_table_class
  customer_metadata_table_RCU                 = var.customer_metadata_table_RCU
  customer_metadata_table_WCU                 = var.customer_metadata_table_WCU
  customer_metadata_table_autoscaling_enabled = var.customer_metadata_table_autoscaling_enabled
  customer_metadata_table_hash_partition_key  = var.customer_metadata_table_hash_partition_key
  customer_metadata_table_max_RWcapacity      = var.customer_metadata_table_max_RWcapacity
  customer_metadata_table_min_RWcapacity      = var.customer_metadata_table_min_RWcapacity
  customer_metadata_table_target_scaling_val  = var.customer_metadata_table_target_scaling_val
}

module "app_notification_sns" {
  source                          = "../../modules/sns"
  app_notification_email_endpoint = var.app_notification_email_endpoint
  app_notification_kms_key        = var.app_notification_kms_key
  app_notification_sns_name       = var.app_notification_sns_name
}

module "document_lambda" {
  source                      = "../../modules/lambda"
  document_lambda_policy_name = var.document_lambda_policy_name
  document_lambda_role_name   = var.document_lambda_role_name
  document_s3_bucket_arn      = module.document_s3_bucket.document_bucket_arn
  dynamodb_metadata_table_arn = module.customer_metadata_dynamo_db_table.customer_metadata_table_arn
  sns_topic_arn = module.app_notification_sns.sns_topic_arn
}
