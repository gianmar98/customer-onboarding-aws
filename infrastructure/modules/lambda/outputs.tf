# Lambda IAM -------------------------------------------------------------------------
output "document_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.document_lambda_role.arn
}

output "document_lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.document_lambda_role.name
}
