output "sqs_license_queue_arn" {
  description = "This is the ARN of the default SQS licence queue"
  value       = aws_sqs_queue.license_queue.arn
}

output "sqs_license_dead_letter_queue_arn" {
  description = "This is the ARN of the DLQ SQS licence queue"
  value       = aws_sqs_queue.license_dead_letter_queue.arn
}

output "sqs_license_queue_name" {
  description = "This is the name of the SQS queue my document lambda function will be writing to"
  value       = aws_sqs_queue.license_queue.name
}

output "sqs_url" {
  description = "URL of SQS queue"
  value       = aws_sqs_queue.license_queue.url
}
