module "document_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"
  bucket  = var.document_s3_bucket_name

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }


  #BLOCK PUBLIC ACCESS IS DEFAULT
}

resource "aws_s3_bucket_policy" "document_bucket_tls_only" {
  bucket = module.document_s3_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.ssl_only_policy.json
}

data "aws_iam_policy_document" "ssl_only_policy" {
  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      module.document_s3_bucket.s3_bucket_arn,
      "${module.document_s3_bucket.s3_bucket_arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}