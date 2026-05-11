terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Optional: Use specific profile if needed
  # profile = "default"

  # Optional: Add default tags for all resources
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Module    = "terraform-aws-oidc-provider-examples"
    }
  }
}
