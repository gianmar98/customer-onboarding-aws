# aws sqs get-queue-url --queue-name LicenseQueue --output text

# aws sqs send-message --queue-url $QueueUrl --message-body '{"driver_license_id": "S123456579010", "validation_override": true, "uuid": "8d247914"}'
# aws sqs send-message --queue-url https://sqs.us-east-1.amazonaws.com/<account-id>/LicenseQueue --message-body '{"driver_license_id": "S123456579010", "validation_override": true, "uuid": "8d247914"}'


#Main SQS Queue
resource "aws_sqs_queue" "license_queue" {
  name = var.sqs_queue_name
  # Must be >= 6x the consumer's function timeout (SubmitLicenseLambdaFunction, var.lambda_functions_timeout = 20s)
  # so a slow invocation can't have its message redelivered while it's still being processed.
  # Also sets the retry pacing below: a failing message waits this long between receives.
  visibility_timeout_seconds = 120
  fifo_queue                 = false #standard Queue

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.license_dead_letter_queue.arn
    # 3 receives x 120s visibility = a bad message reaches the DLQ in ~4 min instead of ~20.
    # Enough retries to ride out a transient API Gateway/DynamoDB blip, few enough that a
    # genuinely bad application surfaces fast. Only reachable because submit_license.py
    # re-raises on error - a Lambda that returns is a success and the message is deleted.
    maxReceiveCount = 3
  })
}


# DLQ QUEUE
resource "aws_sqs_queue" "license_dead_letter_queue" {
  name       = var.sqs_dlq_name
  fifo_queue = false #standard Queue

}

resource "aws_sqs_queue_redrive_allow_policy" "terraform_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.license_dead_letter_queue.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.license_queue.arn]
  })
}
