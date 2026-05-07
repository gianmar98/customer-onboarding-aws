resource "aws_iam_role" "DocumentLambdaRole" { #the identity (Lambda) itself, with the role attached
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

resource "aws_iam_role_policy" "DocumentLambdaPolicy" { # what the identity is allowed to do
  role = aws_iam_role.DocumentLambdaRole.id
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

        Resource = "${module.document-s3-bucket.s3_bucket_arn}/*"
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