locals {
  name                   = "${var.company_name}-${var.environment}"
  airbyte_rds_identifier = "${local.name}-airbyte"
  enable_webhook         = var.create && var.environment == "dev"
}
