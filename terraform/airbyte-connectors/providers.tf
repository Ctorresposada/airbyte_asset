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
      Stack       = "airbyte-connections"
    }
  }
}

# Airbyte API provider. server_url is constructed from the Airbyte instance hostname.
# For self-hosted Airbyte the public API lives at /api/public/v1/.
# client_id / client_secret are sourced from env vars (TF_VAR_airbyte_client_id / TF_VAR_airbyte_client_secret).
provider "airbyte" {
  server_url    = "http://${var.airbyte_hostname}/api/public/v1"
  client_id     = var.airbyte_client_id
  client_secret = var.airbyte_client_secret
  token_url     = "http://${var.airbyte_hostname}/api/public/v1/applications/token"
}

provider "airbyte" {
  alias         = "airbyte_cloud"
  client_id     = var.airbyte_cloud_client_id
  client_secret = var.airbyte_cloud_client_secret
}

