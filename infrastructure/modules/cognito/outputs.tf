output "cognito_user_pool_name" {
  description = "Name of the Cognito user pool"
  value       = aws_cognito_user_pool.license_validation_users.name
}

output "cognito_user_pool_client_name" {
  description = "Name of the Cognito user pool Client"
  value       = aws_cognito_user_pool_client.web.name
}

output "user_pool_id" {
  description = "Cognito user pool ID (frontend NEXT_PUBLIC_USER_POOL_ID)."
  value       = aws_cognito_user_pool.license_validation_users.id
}

output "user_pool_client_id" {
  description = "App client ID (frontend NEXT_PUBLIC_USER_POOL_CLIENT_ID + JWT audience)."
  value       = aws_cognito_user_pool_client.web.id
}

# endpoint = "cognito-idp.<region>.amazonaws.com/<pool-id>"; the JWT issuer is https:// + this.
output "issuer" {
  description = "JWT issuer URL for the API Gateway JWT authorizer."
  value       = "https://${aws_cognito_user_pool.license_validation_users.endpoint}"
}