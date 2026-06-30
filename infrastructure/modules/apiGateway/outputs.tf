output "validate_license_api_arn" {
  description = "ARN of the ValidateLicense HTTP API"
  value       = aws_apigatewayv2_api.validate_license_api.arn
}

output "validate_license_api_name" {
  description = "Name of the API GW that will receive the submission and send it to validate lambda function"
  value       = aws_apigatewayv2_api.validate_license_api.name
}

output "license_validation_invoke_url" {
  description = "Invoke URL for POST /license"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/license"
}