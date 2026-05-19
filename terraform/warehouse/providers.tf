provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/region-20-terraform-execution-role"
  }

  default_tags {
    tags = {
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "Terraform"
      Stack       = "warehouse"
    }
  }
}
