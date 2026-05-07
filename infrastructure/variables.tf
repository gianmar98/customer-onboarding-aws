// CONTAINER FOR ALL VARIABLES

variable "document_s3_bucket_name" {
  description = "This is the name of the document S3 bucket for the project"
  type        = string
}

variable "document_lambda_role_name" {
  description = "Role of Lambda to r/w/delete with policy attached"
  type        = string
}

variable "document_lambda_policy_name" {
  description = "Policy to be attached to lambda function that it can read, write, and delete objects from the document bucket"
  type = string
}