# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# S3 ---------------------------------------------------------------------------------
variable "document_s3_bucket_name" {
  description = "Name of the document S3 bucket"
  type        = string
}

variable "document_retention_days" {
  description = "Days after upload that identity documents (zipped/ and unzipped/) are expired"
  type        = number
  default     = 30

  validation {
    condition     = var.document_retention_days > 0
    error_message = "document_retention_days must be greater than 0."
  }
}