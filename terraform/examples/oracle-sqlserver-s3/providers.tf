provider "airbyte" {
  server_url  = var.airbyte_server_url
  bearer_auth = data.external.airbyte_token.result["access_token"]
}

# AWS provider for Secrets Manager lookups (source DB passwords)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
