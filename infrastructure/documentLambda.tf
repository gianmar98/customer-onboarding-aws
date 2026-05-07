
resource "aws_iam_role_policy" "DocumentLambdaPolicy" { # what the identity is allowed to do
  role = aws_iam_role.DocumentLambdaRole.id
  name = var.document_lambda_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect   = "Allow"
        Resource = "${module.document-s3-bucket.s3_bucket_arn}/*"
      },
    ]
  })
}



resource "aws_iam_role" "DocumentLambdaRole" { #the identity (Lambda) itself, with the role attached
  name                 = var.document_lambda_role_name
  # permissions_boundary = data.aws_iam_policy.role_boundary.arn #Have not been implemented

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



# {
# 	"Version": "2012-10-17",
# 	"Statement": [
# 		{
# 			"Sid": "S3GetPutDelete",
# 			"Effect": "Allow",
# 			"Action": [
# 				"s3:GetObject",
# 				"s3:PutObject",
# 				"s3:DeleteObject"
# 			],
# 			"Resource": [
# 				"arn:aws:s3:::documentbucket-aci1/*"
# 			]
# 		}
# 	]
# }
