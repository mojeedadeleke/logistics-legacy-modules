terraform {
  # Variable validations reference another variables and local,
  # which became possible in Terraform 1.9 upward
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}