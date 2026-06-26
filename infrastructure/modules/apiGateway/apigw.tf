#TEST API INVOKE ENDPOINT
# curl -X POST -H 'Content-Type: application/json' -d '{"driver_license_id": "S123456579010", "validation_override": "True"}' $API_ENDPOINT_URL

# curl -X POST -H 'Content-Type: application/json' -d '{"driver_license_id": "S123456579010", "validation_override": "False"}' $API_ENDPOINT_URL

#aws logs tail /aws/lambda/ValidateLicenseLambdaFunctionU

#The API itself
resource "aws_apigatewayv2_api" "validate_license_api" {
  name          = var.validate_api_gw_name
  protocol_type = "HTTP"
}

#The target, what to call when request arrives (AWS Proxy means send request to lambda and return what lambda returns)
resource "aws_apigatewayv2_integration" "validation_integration" {
  api_id                 = aws_apigatewayv2_api.validate_license_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.validate_lambda_invoke_arn
  payload_format_version = "2.0"
}

#Rule that maps POST /license integration
resource "aws_apigatewayv2_route" "post_license" {
  api_id    = aws_apigatewayv2_api.validate_license_api.id
  route_key = "POST /license"
  target    = "integrations/${aws_apigatewayv2_integration.validation_integration.id}"
}

#Deployment slot where APIs can live ($default is the catch-all stage) (auto deploy deploy changes instantly)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.validate_license_api.id
  name        = "$default"
  auto_deploy = true
}

#IAM Door
resource "aws_lambda_permission" "apigw_invoke_validate" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.validate_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.validate_license_api.execution_arn}/*/*"
}