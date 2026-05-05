module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket = "documentbucket-aci1"

   server_side_encryption_configuration = {
      rule = {
        apply_server_side_encryption_by_default = {
          sse_algorithm = "AES256"
        }
      }
    }

  //BLOCK PUBLIC ACCESS IS DEFAULT
}

resource "aws_s3_bucket_policy" "s3BucketPolicyTLS" {
  bucket = module.s3-bucket.s3_bucket_id
  policy = file("./AllowSSLOnlyS3Policy.json")
}