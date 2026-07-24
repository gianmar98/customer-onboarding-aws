# Package the Lambda function code
data "archive_file" "validate_lambda_function_archive_file" {
  type        = "zip"
  source_file = "${path.module}/src/validate_lambda.py"
  output_path = "${path.module}/build/validate_lambda.zip"
}


# Lambda function
resource "aws_lambda_function" "validation_lambda_function" {
  description   = "Mock Lambda function to simulate 3rd party validation both True and False license use cases"
  filename      = data.archive_file.validate_lambda_function_archive_file.output_path
  function_name = var.validate_lambda_function_name
  role          = aws_iam_role.validation_lambda_role.arn
  handler       = "validate_lambda.lambda_handler"

  #Hash being shipped. If this value differs from the original one, treat the function as changed and redeploy it.
  source_code_hash = data.archive_file.validate_lambda_function_archive_file.output_base64sha256

  runtime = "python3.13"

  timeout = var.lambda_functions_timeout

  logging_config {
    log_group  = aws_cloudwatch_log_group.validation_lambda_logs.name
    log_format = "Text"
  }

  # environment {
  #   variables = {
  #     TABLE = var.dynamodb_document_table_name
  #     TOPIC = var.sns_topic_arn
  #   }
  # }
}