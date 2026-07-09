# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# DOCUMENT Lambda IAM -------------------------------------------------------------------------
variable "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  type        = string
}
variable "document_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}
variable "current_region" {
  description = "Current project region of deployment"
  type        = string
}
variable "current_account_id" {
  description = "Current account ID"
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


# VALIDATION Lambda --------------------------------
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

# SUBMIT LICENSE Lambda --------------------------------
variable "submit_license_lambda_function_name" {
  description = "This is the name for my Lambda function to submit licenses"
  type        = string
}
variable "submit_license_lambda_role_name" {
  description = "This is the name of the Role of my submit license lambda function"
  type        = string
}
variable "submit_license_lambda_cloudwatch_logs_policy_name" {
  description = "Name of the CloudWatch Logs Policy for my submit license Lambda"
  type        = string
}
variable "submit_license_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}

# UNZIP lambda function
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

# WRITE TO DYNAMO lambda function
variable "write_to_dynamo_lambda_function_name" {
  description = "Name of the lambda function that will write to the lambda function after receiving the app_uuid from the unzip lambda function"
  type        = string
}
variable "write_to_dynamo_lambda_function_role_name" {
  description = "name of the role the lambda function that writes to DynamoDB would assume"
  type        = string
}
variable "write_to_dynamo_lambda_cloudwatch_logs_policy_name" {
  description = "name of the cloudwatch logs policy for the write to dynamoDB lambda function"
  type        = string
}

# COMPARE FACES lambda function
variable "compare_faces_lambda_function_name" {
  description = "Name of the lambda function that will compare the user face and the license"
  type        = string
}
variable "compare_faces_lambda_function_role_name" {
  description = "name of the role the lambda function that compares faces would assume"
  type        = string
}
variable "compare_faces_lambda_cloudwatch_logs_policy_name" {
  description = "name of the cloudwatch logs policy for the compare faceslambda function"
  type        = string
}
variable "compare_faces_lambda_policy_name" {
  description = "Name of the inline policy attached to the Lambda execution role"
  type        = string
}


#  OUTPUTS TO USE --------------------------
# S3
variable "document_s3_bucket_arn" {
  description = "ARN of the document S3 bucket Lambda needs to access to"
  type        = string
}
variable "document_s3_bucket_name" {
  description = "Name of the document S3 Bucket will be reacting to"
  type        = string
}
# DYNAMODB
variable "dynamodb_metadata_table_arn" {
  description = "ARN of the dynamoDB metadata table that Lambda needs to access to"
  type        = string
}
variable "dynamodb_document_table_name" {
  description = "This is the name that will be referenced from lambda ENV variable form DynamoDB table"
  type        = string
}
# SNS
variable "sns_topic_arn" {
  description = "ARN of the SNS topic that Lambda needs to access"
  type        = string
}
variable "sns_topic_name" {
  description = "Name of the SNS Topic that Lambda needs as ENV variable"
  type        = string
}
# SQS
variable "sqs_license_queue_arn" {
  description = "This is the ARN of the main license submission SQS queue"
  type        = string
}
variable "sqs_license_queue_name" {
  description = "This is the name of the SQS queue my document lambda function will be writing to"
  type        = string
}
variable "sqs_submit_license_policy_name" {
  description = "This is the name of the policy that allows SQS to invoke lambda"
  type        = string
}
variable "sqs_url" {
  description = "URL of SQS to send payload from Document Lambda Function"
  type        = string
}

# API GW
variable "validate_license_api_name" {
  description = "This is the name of the API GW that will receive the submission and send it to validate lambda function"
  type        = string
}
variable "validate_license_api_url" {
  description = "The invoke URL for the API GW to use in Submit Lambda function"
  type        = string
}



