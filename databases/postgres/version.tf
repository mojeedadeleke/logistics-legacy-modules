terraform {
  required_version = ">= 1.9.0, < 2.0.0" # Why: Referenced another variable within validation block

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}