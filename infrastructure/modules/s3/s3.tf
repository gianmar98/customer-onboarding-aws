# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

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

resource "aws_s3_object" "zipped_prefix" {
  bucket = module.document_s3_bucket.s3_bucket_id
  key    = "zipped/"
}