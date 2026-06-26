output "validate_license_api_arn" {
  description = "ARN of the ValidateLicense HTTP API"
  value       = aws_apigatewayv2_api.validate_license_api.arn
}

output "license_validation_invoke_url" {
  description = "Invoke URL for POST /license"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/license"
}