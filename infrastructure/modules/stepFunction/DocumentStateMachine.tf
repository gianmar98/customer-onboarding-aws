
# ...

resource "aws_sfn_state_machine" "document_state_machine" {
  name     = var.document_state_machine_name
  role_arn = aws_iam_role.document_state_machine_iam_role.arn

  definition = <<EOF
{
  "Comment": "A Hello World example of the Amazon States Language using an AWS Lambda Function",
  "StartAt": "UnzipLambdaFunction",
  "States": {
    "UnzipLambdaFunction": {
      "Type": "Task",
      "Resource": "${var.unzip_lambda_function_arn}",
      "Next": "WriteToDynamoLambdaFunction"
    },
    "WriteToDynamoLambdaFunction": {
      "Type": "Task",
      "Resource": "${var.write_to_dynamo_lambda_arn}",
      "Next": "PerformParallelChecks"
    },
    "PerformParallelChecks": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "CompareFacesLambdaFunction",
          "States": {
            "CompareFacesLambdaFunction": {
              "Type": "Pass",
              "Result": "Data from Branch 1 (Compare Faces)",
              "End": true
            }
          }
        },
        {
          "StartAt": "CompareDetailsLambdaFunction",
          "States": {
            "CompareDetailsLambdaFunction": {
              "Type": "Pass",
              "Result": "Data from Branch 2 (Compare Details)",
              "End": true
            }
          }
        }
      ],
      "ResultPath": "$.parallelResults",
      "Next": "ValidateSQSQueue"
    },
    "ValidateSQSQueue": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sqs:sendMessage",
      "Parameters": {
        "QueueUrl": "${var.validate_sqs_queue_url}",
        "MessageBody.$": "$"
      },
      "End": true
    }
  }
}
EOF
}


resource "aws_iam_role" "document_state_machine_iam_role" {
  name = var.document_state_machine_iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })

}