# Package the Lambda function code
data "archive_file" "document_lambda_function_archive_file" {
  type        = "zip"
  source_file = "${path.module}/src/s3_upload.py"
  output_path = "${path.module}/build/s3_upload.zip"
}

# Lambda function
resource "aws_lambda_function" "document_lambda_function" {
  description   = "Processes customer application zips from S3: extracts files, persists data to DynamoDB, validates ID via Rekognition + Textract + SQS, and notifies via SNS."
  filename      = data.archive_file.document_lambda_function_archive_file.output_path
  function_name = var.document_lambda_function_name
  role          = aws_iam_role.document_lambda_role.arn
  handler       = "s3_upload.lambda_handler"

  #Hash being shipped. If this value differs from the original one, treat the function as changed and redeploy it.
  source_code_hash = data.archive_file.document_lambda_function_archive_file.output_base64sha256

  runtime = "python3.13"

  timeout = var.document_lambda_function_timeout

  logging_config {
    log_group  = aws_cloudwatch_log_group.document_lambda_logs.name
    log_format = "Text"
  }

  environment {
    variables = {
      TABLE = var.dynamodb_document_table_name
      TOPIC = var.sns_topic_arn
    }
  }
}


resource "aws_s3_bucket_notification" "document_bucket_notification" {
  bucket = var.document_s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.document_lambda_function.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_prefix       = "zipped/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}


resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.document_s3_bucket_arn
}
