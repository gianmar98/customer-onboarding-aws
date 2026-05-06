output "document_bucket_name" {
  value = module.document-s3-bucket.s3_bucket_id
  description = "The name of the document S3 bucket"
}
