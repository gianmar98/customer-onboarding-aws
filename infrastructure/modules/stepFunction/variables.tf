variable "document_state_machine_name" {
  description = "This is the name of the Document State Machine that orchestrates all 4 lambda functions (Unzip -> Write to Dynamo -> [Parallel] Compare Faces & Compare Details -> SQS Queue)"
  type        = string
}
variable "document_state_machine_iam_role_name" {
  description = "This is the name of the IAM role the Document Step Function will assume"
  type        = string
}



variable "unzip_lambda_function_arn" {
  description = "This is the ARN of the 1st lambda function of the Step Function"
  type        = string
}

variable "write_to_dynamo_lambda_arn" {
  description = "This is the ARN of the 2nd lambda function of the Step Function"
  type        = string
}

variable "compare_faces_lambda_function_arn" {
  description = "This is the ARN of the 3rd(a) lambda function of the Step Function"
  type        = string
}

variable "compare_details_lambda_function_arn" {
  description = "This is the ARN of the 3rd(b) lambda function of the Step Function"
  type        = string
}

variable "validate_sqs_queue_url" {
  description = "This is the URL of the SQS queue to validate the license with 3rd party"
  type        = string
}