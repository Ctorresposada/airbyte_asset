locals {
  name         = "${var.company_name}-${var.environment}"
  compute_name = "Reg20DBT${title(var.environment)}01"
  # Falls back to :initial only when the data source has no instances (count = 0).
  dbt_image = try(
    jsondecode(data.aws_ecs_task_definition.dbt_core_current[0].container_definitions)[0].image,
    "${var.ecr_repository_url}:initial"
  )
}
