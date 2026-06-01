terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    airbyte = {
      source  = "airbytehq/airbyte"
      version = "~> 1.2"
    }
  }

  backend "s3" {
    bucket       = "region-20-tf-state"
    key          = "airbyte-connections/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    kms_key_id   = "arn:aws:kms:us-east-1:471624149663:key/77d58064-e84b-4646-ae3d-180ec68f4625"
  }
}
