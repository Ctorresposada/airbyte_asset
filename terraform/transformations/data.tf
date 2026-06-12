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

data "aws_s3_bucket" "bronze" {
  count = var.create ? 1 : 0

  bucket = "escr20-bronze-${var.environment}"
}

data "aws_s3_bucket" "raw" {
  count = var.create ? 1 : 0

  bucket = "escr20-landing-zone-raw-${var.environment}"
}

# CI writes the deployed image URI here after every successful ECR push.
# Terraform reads it so the task definition always gets the CI-managed tag.
# Parameter is created by aws_ssm_parameter.dbt_image_uri in main.tf.
data "aws_ssm_parameter" "dbt_image_uri" {
  count = var.create && var.enable_dbt_task ? 1 : 0

  name            = var.dbt_image_ssm_parameter_name
  with_decryption = false
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

  workgroup_name = local.warehouse_wg_name
}

