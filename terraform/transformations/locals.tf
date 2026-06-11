locals {
  name              = "${var.company_name}-${var.environment}"
  compute_name      = "Reg20DBT${title(var.environment)}01"
  warehouse_wg_name = "${local.name}-warehouse-wg"
  # Falls back to :initial only when the data source has no instances (count = 0).
  dbt_image = try(
    data.aws_ssm_parameter.dbt_image_uri[0].value,
    "${var.ecr_repository_url}:initial"
  )
}
