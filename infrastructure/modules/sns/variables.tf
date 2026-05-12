# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

# SNS --------------------------------------------------------------------------------
variable "app_notification_sns_name" {
  description = "Name of the application notifications SNS topic"
  type        = string
}

variable "app_notification_kms_key" {
  description = "KMS master key id/alias used to encrypt the SNS topic"
  type        = string
}

variable "app_notification_email_endpoint" {
  description = "Email address subscribed to the SNS topic (requires manual confirmation)"
  type        = string
}