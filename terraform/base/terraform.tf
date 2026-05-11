terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "region-20-tf-state"
    key          = "base/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
    kms_key_id   = "arn:aws:kms:us-east-1:471624149663:key/77d58064-e84b-4646-ae3d-180ec68f4625"
  }
}
