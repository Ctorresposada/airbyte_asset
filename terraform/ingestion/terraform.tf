terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # archive provider retained for state compatibility — was used in a previous
    # partial apply and cannot be removed until the state is migrated or refreshed.
    # tflint-ignore: terraform_unused_required_providers
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket       = "region-20-tf-state"
    key          = "ingestion/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    kms_key_id   = "arn:aws:kms:us-east-1:471624149663:key/77d58064-e84b-4646-ae3d-180ec68f4625"
  }
}