resource "aws_iam_role" "document_lambda_role" { #the identity (Lambda) itself, with the role attached
  name = var.document_lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = var.document_lambda_role_name
        Principal = { #Trusted entity type (Lambda)
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

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
      { # Adding CloudWatch Logs to be able to debug Lambda function
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}