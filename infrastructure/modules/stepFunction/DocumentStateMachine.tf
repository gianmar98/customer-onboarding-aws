
# STATE MACHINE RESOURCE
resource "aws_sfn_state_machine" "document_state_machine" {
  name     = var.document_state_machine_name
  role_arn = aws_iam_role.document_state_machine_iam_role.arn

  definition = <<EOF
{
  "Comment": "This is the Step Function that orchestrates License validation",
  "StartAt": "UnzipLambdaFunction",
  "States": {
    "UnzipLambdaFunction": {
      "Type": "Task",
      "Resource": "${var.unzip_lambda_function_arn}",
      "ResultPath": "$.application",
      "Next": "WriteToDynamoLambdaFunction"
    },
    "WriteToDynamoLambdaFunction": {
      "Type": "Task",
      "Resource": "${var.write_to_dynamo_lambda_arn}",
      "ResultPath": "$.validation",
      "Next": "PerformParallelChecks"
    },
    "PerformParallelChecks": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "CompareFacesLambdaFunction",
          "States": {
            "CompareFacesLambdaFunction": {
              "Type": "Task",
              "Resource": "${var.compare_faces_lambda_function_arn}",
              "End": true
            }
          }
        },
        {
          "StartAt": "CompareDetailsLambdaFunction",
          "States": {
            "CompareDetailsLambdaFunction": {
              "Type": "Task",
              "Resource": "${var.compare_details_lambda_function_arn}",
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
        "MessageBody": {
          "driver_license_id.$": "$.validation.driver_license_id",
          "validation_override.$": "$.validation.validation_override",
          "uuid.$": "$.validation.app_uuid"
        }
      },
      "End": true
    }
  }
}
EOF

  #Enable AWS X-Ray tracing
  tracing_configuration {
    enabled = true
  }
}
#Allow Step Functions to assume IAM role
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
#Step Functions policy attachment to role
resource "aws_iam_role_policy" "document_state_machine_policy" {
  name = "AllowStepFunctionsToAssumeRole"
  role = aws_iam_role.document_state_machine_iam_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.unzip_lambda_function_arn,
          var.write_to_dynamo_lambda_arn,
          var.compare_details_lambda_function_arn,
          var.compare_faces_lambda_function_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = [
          var.validate_sqs_queue_arn
        ]
      },
      {
        # X-Ray API calls don't support resource-level permissions
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = ["*"]
      }
    ]
  })
}

#S3 TO==>> EVENT BRIDGE NOTIFICATION
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = var.document_s3_bucket_id
  eventbridge = true
}

#CloudWatchEvent on upload
resource "aws_cloudwatch_event_rule" "zipped_object_created" {
  name = "${var.document_state_machine_name}-zipped-object-created"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.document_s3_bucket_name]
      }
      object = {
        # One wildcard matcher, not [{prefix = "zipped/"}, {suffix = ".zip"}] - EventBridge
        # ORs the elements of a matcher array, so that form would BROADEN the filter to
        # "anything under zipped/ OR any .zip anywhere" rather than narrowing it.
        key = [{ wildcard = "zipped/*.zip" }]
      }
    }
  })
}
#CloudWatch Event Target -> Step Function
resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.zipped_object_created.name
  arn      = aws_sfn_state_machine.document_state_machine.arn
  role_arn = aws_iam_role.eventbridge_sfn_role.arn
}
#EventBridge role creation
resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "${var.document_state_machine_iam_role_name}-eventbridge"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}
#^^EventBridge policy attachment to role ^^
resource "aws_iam_role_policy" "eventbridge_start_execution" {
  name = "AllowEventBridgeStartExecution"
  role = aws_iam_role.eventbridge_sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.document_state_machine.arn
      },
    ]
  })
}
