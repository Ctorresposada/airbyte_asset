data "aws_vpc" "this" {
  count = var.create ? 1 : 0

  tags = {
    Name = local.name
  }
}

data "aws_subnets" "private" {
  count = var.create ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  tags = {
    Tier = "private-app"
  }
}

# External buckets owned by other stacks — dbt writes Athena query results here
# and reads silver-layer source data. Looked up, not created by this stack.
data "aws_s3_bucket" "athena_results" {
  count = var.create ? 1 : 0

  bucket = "escr20-athena-results-${var.environment}"
}

data "aws_s3_bucket" "silver" {
  count = var.create ? 1 : 0

  bucket = "escr20-silver-${var.environment}"
}

# Reads the currently deployed revision to preserve the CI-managed image tag on
# subsequent applies. Requires the task family to already exist — on a brand-new
# environment do a first apply with image = "${var.ecr_repository_url}:initial"
# hardcoded, then switch to this pattern.
data "aws_ecs_task_definition" "dbt_core_current" {
  count           = var.create && var.enable_dbt_task ? 1 : 0
  task_definition = "${local.name}-dbt-core"
}

# Redshift Serverless SG owned by the warehouse stack — looked up here so the dbt
# Core ECS ingress rule can target it without a cross-stack circular dependency.
data "aws_security_group" "redshift" {
  count = var.create ? 1 : 0

  tags = {
    Name = "${local.name}-redshift"
  }
}

# Redshift Serverless workgroup owned by the warehouse stack — looked up here to
# source the endpoint address injected into the dbt task as REDSHIFT_HOST. Avoids
# a cross-stack terraform_remote_state dependency.
data "aws_redshiftserverless_workgroup" "this" {
  count = var.create ? 1 : 0

  workgroup_name = "${local.name}-warehouse-wg"
}

