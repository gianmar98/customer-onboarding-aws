variable "validate_api_gw_name" {
  description = "This is the name of the API GW that will trigger the validation Lambda"
  type        = string
}

variable "validate_lambda_invoke_arn" {
  description = "Invoke ARN of the validation Lambda"
  type        = string
}

variable "validate_lambda_function_name" {
  description = "Function name of the validation Lambda"
  type        = string
}