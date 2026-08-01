# Copyright (c) 2026 Giancarlo Martinez
# SPDX-License-Identifier: MIT

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4"
    }
  }
}
