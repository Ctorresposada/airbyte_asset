locals {
  name         = "${var.company_name}-${var.environment}"
  compute_name = "Reg20DBT${title(var.environment)}01"
}
