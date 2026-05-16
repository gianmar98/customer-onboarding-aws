# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# Lambda IAM -------------------------------------------------------------------------
output "document_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.document_lambda_role.arn
}

output "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.document_lambda_role.name
}

output "document_lambda_function_arn" {
  description = "This is the ARN of the document Lambda Function"
  value       = aws_lambda_function.document_lambda_function.arn
}

output "document_lambda_function_name" {
  description = "This is the name of the document Lambda Function"
  value       = aws_lambda_function.document_lambda_function.function_name
}
