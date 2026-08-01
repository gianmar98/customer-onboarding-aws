
# Package the Lambda function code
data "archive_file" "write_to_dynamo_lambda_function_archive_file" {
  type        = "zip"
  source_file = "${path.module}/src/write_to_dynamo_lambda.py"
  output_path = "${path.module}/build/write_to_dynamo_lambda.zip"
}


# Lambda function
resource "aws_lambda_function" "write_to_dynamo_lambda_function" {
  description   = "Lambda function to write to DynamoDB"
  filename      = data.archive_file.write_to_dynamo_lambda_function_archive_file.output_path
  function_name = var.write_to_dynamo_lambda_function_name
  role          = aws_iam_role.write_to_dynamo_lambda_role.arn
  handler       = "write_to_dynamo_lambda.lambda_handler"

  #Hash being shipped. If this value differs from the original one, treat the function as changed and redeploy it.
  source_code_hash = data.archive_file.write_to_dynamo_lambda_function_archive_file.output_base64sha256

  runtime = "python3.13"

  timeout = var.lambda_functions_timeout

  # AWS-hosted Lambda Powertools layer — provides the Tracer used to emit X-Ray subsegments.
  # Must match the runtime above (python313) and the architecture; version is pinned.
  # arn:aws:lambda: region : account :layer: name : version
  layers = ["arn:aws:lambda:${var.current_region}:017000801446:layer:AWSLambdaPowertoolsPythonV3-python313-x86_64:36"]

  logging_config {
    log_group  = aws_cloudwatch_log_group.write_to_dynamo_lambda_logs.name
    log_format = "Text"
  }

  environment {
    variables = {
      TABLE = var.dynamodb_document_table_name
      # Names this service in the X-Ray trace map; Powertools defaults to "service_undefined" without it.
      POWERTOOLS_SERVICE_NAME = var.project_name
      # TOPIC   = var.sns_topic_arn
      # SQS_URL = var.sqs_url
    }
  }

  tracing_config {
    mode = "Active"
  }
}
