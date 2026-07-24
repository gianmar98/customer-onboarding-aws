# Package the Lambda function code
data "archive_file" "compare_details_lambda_function_archive_file" {
  type        = "zip"
  source_file = "${path.module}/src/compare_details_lambda.py"
  output_path = "${path.module}/build/compare_details_lambda.zip"
}


# Lambda function
resource "aws_lambda_function" "compare_details_lambda_function" {
  description   = "Lambda function to compare details"
  filename      = data.archive_file.compare_details_lambda_function_archive_file.output_path
  function_name = var.compare_details_lambda_function_name
  role          = aws_iam_role.compare_details_lambda_role.arn
  handler       = "compare_details_lambda.lambda_handler"

  #Hash being shipped. If this value differs from the original one, treat the function as changed and redeploy it.
  source_code_hash = data.archive_file.compare_details_lambda_function_archive_file.output_base64sha256

  runtime = "python3.13"

  timeout = var.lambda_functions_timeout

  logging_config {
    log_group  = aws_cloudwatch_log_group.compare_details_lambda_logs.name
    log_format = "Text"
  }

  environment {
    variables = {
      TABLE = var.dynamodb_document_table_name
      TOPIC = var.sns_topic_arn
    }
  }
}
