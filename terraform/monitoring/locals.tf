locals {
  name                   = "${var.company_name}-${var.environment}"
  airbyte_rds_identifier = "${local.name}-airbyte"
}
