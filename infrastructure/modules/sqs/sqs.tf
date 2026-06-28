
#Main SQS Queue
resource "aws_sqs_queue" "license_queue" {
  name = var.sqs_queue_name
  visibility_timeout_seconds = 300
  fifo_queue = false #standard Queue

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.license_dead_letter_queue.arn
    maxReceiveCount     = 5
  })
}


# DLQ QUEUE
resource "aws_sqs_queue" "license_dead_letter_queue" {
  name = var.sqs_dlq_name
  fifo_queue = false #standard Queue

}

resource "aws_sqs_queue_redrive_allow_policy" "terraform_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.license_dead_letter_queue.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.license_queue.arn]
  })
}
