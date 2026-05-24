# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

locals {
  log_group_name        = "/aws/lambda/${var.document_lambda_function_name}"
  logs_group_create_arn = "arn:aws:logs:${var.current_region}:${var.current_account_id}:*"
  log_stream_arn_prefix = "arn:aws:logs:${var.current_region}:${var.current_account_id}:log-group:${local.log_group_name}:*"
}

resource "aws_iam_role" "document_lambda_role" { #the identity (Lambda) itself, with the role attached
  name = var.document_lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "DocumentLambdaRole"
        Principal = { #Trusted entity type (Lambda)
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

#INLINE POLICY
resource "aws_iam_role_policy" "document_lambda_policy" { # what the identity is allowed to do
  role = aws_iam_role.document_lambda_role.id
  name = var.document_lambda_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # S3 Get, Put, and Delete objects from Lambda
        Sid    = "S3AccessPolicy"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],

        Resource = "${var.document_s3_bucket_arn}/*"
      },
      { # Write and update items to the newly created DynamoDB table.
        Sid    = "DynamoDBAccessPolicy"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = var.dynamodb_metadata_table_arn
      },
      { # Publish to the newly created SNS Topic.
        Sid    = "SNSTopicAccessPolicy"
        Effect = "Allow"
        Action = [
          "sns:Publish",
        ],
        Resource = var.sns_topic_arn
      },
    ]
  })
}

#MANAGED POLICY
resource "aws_iam_policy" "lambda_cloudwatch_logs_policy" { # what the identity is allowed to do
  name = var.lambda_cloudwatch_logs_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # Create Log Group
        Sid    = "CloudWatchLogGroupCreation"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
        ]
        Resource = local.logs_group_create_arn
      },
      { # Resource is scoped to this Lambda's own log group
        Sid    = "CloudWatchLogsStreamAndPut"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = local.log_stream_arn_prefix
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_CloudWatchPolicy_to_lambdaRole" {
  policy_arn = aws_iam_policy.lambda_cloudwatch_logs_policy.arn
  role       = aws_iam_role.document_lambda_role.name
}
#So I do NOT pay for retention of data older than 14 days
resource "aws_cloudwatch_log_group" "document_lambda_logs" {
  name              = local.log_group_name
  retention_in_days = 14
}



#MANAGED POLICY
resource "aws_iam_policy" "rekognition_face_comparison_policy" {
  name = var.lambda_rekognition_face_comparison_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LambdaRekonitionFaceComparison",
        Effect   = "Allow"
        Action   = ["rekognition:CompareFaces"],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_rekognition_policy_to_lambda" {
  policy_arn = aws_iam_policy.rekognition_face_comparison_policy.arn
  role       = aws_iam_role.document_lambda_role.name
}
