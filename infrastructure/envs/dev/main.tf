# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4"
    }
  }
}

data "aws_caller_identity" "currentUser" {}
data "aws_region" "currentUser" {}
locals {
  env_suffix = "-${var.project_environment}"
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
  document_s3_bucket_name = "${var.document_s3_bucket_name}${local.env_suffix}"
}

module "customer_metadata_dynamo_db_table" {
  source                                      = "../../modules/dynamodb"
  customer_metadata_dynamo_db_table_name      = "${var.customer_metadata_dynamo_db_table_name}${local.env_suffix}"
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
  app_notification_sns_name       = "${var.app_notification_sns_name}${local.env_suffix}"
}

module "document_lambda" {
  # Module Variable = What is being passed to module var
  source = "../../modules/lambda"
  #Project
  current_region     = data.aws_region.currentUser.region
  current_account_id = data.aws_caller_identity.currentUser.account_id

  #Submit Lambda
  document_lambda_policy_name        = "${var.document_lambda_policy_name}${local.env_suffix}"
  document_lambda_role_name          = "${var.document_lambda_role_name}${local.env_suffix}"
  lambda_cloudwatch_logs_policy_name = "${var.lambda_cloudwatch_logs_policy_name}${local.env_suffix}"
  document_lambda_function_name      = "${var.document_lambda_function_name}${local.env_suffix}"
  document_lambda_function_timeout   = var.document_lambda_function_timeout
  sqs_license_queue_name             = module.sqs.sqs_license_queue_name
  sqs_url                            = module.sqs.sqs_url
  #Validate Lambda
  validate_lambda_function_name                 = var.validate_lambda_function_name
  validate_lambda_role_name                     = var.validate_lambda_role_name
  validation_lambda_cloudwatch_logs_policy_name = var.validation_lambda_cloudwatch_logs_policy_name
  #Submit License Lambda
  submit_license_lambda_function_name               = "${var.submit_license_lambda_function_name}${local.env_suffix}"
  submit_license_lambda_role_name                   = "${var.submit_license_lambda_role_name}${local.env_suffix}"
  submit_license_lambda_cloudwatch_logs_policy_name = "${var.submit_license_lambda_cloudwatch_logs_policy_name}${local.env_suffix}"
  submit_license_lambda_policy_name                 = var.submit_license_lambda_policy_name

  #Unzip License lambda
  unzip_lambda_function_name                       = "${var.unzip_lambda_function_name}${local.env_suffix}"
  unzip_lambda_function_role_name                  = var.unzip_lambda_function_role_name
  unzip_license_lambda_cloudwatch_logs_policy_name = var.unzip_license_lambda_cloudwatch_logs_policy_name

  #External
  document_s3_bucket_arn                         = module.document_s3_bucket.document_bucket_arn
  document_s3_bucket_name                        = module.document_s3_bucket.document_bucket_name
  dynamodb_document_table_name                   = module.customer_metadata_dynamo_db_table.customer_metadata_table_name
  dynamodb_metadata_table_arn                    = module.customer_metadata_dynamo_db_table.customer_metadata_table_arn
  lambda_rekognition_face_comparison_policy_name = var.lambda_rekognition_face_comparison_policy_name
  lambda_textract_analyze_id_policy_name         = var.lambda_textract_analyze_id_policy_name
  sns_topic_arn                                  = module.app_notification_sns.sns_topic_arn
  sns_topic_name                                 = module.app_notification_sns.sns_topic_name
  sqs_license_queue_arn                          = module.sqs.sqs_license_queue_arn
  sqs_submit_license_policy_name                 = "${var.sqs_submit_license_policy_name}${local.env_suffix}"
  validate_license_api_name                      = module.api_gateway.validate_license_api_name
  validate_license_api_url                       = module.api_gateway.license_validation_invoke_url
}

module "api_gateway" {
  source               = "../../modules/apiGateway"
  validate_api_gw_name = var.validate_api_gw_name

  #External
  validate_lambda_function_name = var.validate_lambda_function_name
  validate_lambda_invoke_arn    = module.document_lambda.validation_lambda_invoke_arn
}

module "sqs" {
  source         = "../../modules/sqs"
  sqs_queue_name = var.sqs_queue_name
  sqs_dlq_name   = var.sqs_dlq_name
}
