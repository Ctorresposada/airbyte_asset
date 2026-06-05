# ---------------------------------------------------------------------------
# Always-active data sources
# ---------------------------------------------------------------------------

data "aws_caller_identity" "this" {}

# aws_glue_crawler has no data source in the AWS provider — crawler names are
# deterministic from local.name so they are referenced directly where needed.
# aws_lambda_function, aws_redshiftserverless_workgroup, and aws_s3_bucket
# are also not needed: alarms and dashboards reference those resources by name
# string directly, so no data lookup is required.

# ---------------------------------------------------------------------------
# Airbyte data sources — gated on enable_airbyte_monitoring
# ---------------------------------------------------------------------------

data "aws_instance" "airbyte" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  filter {
    name   = "tag:Name"
    values = ["Reg20Airbyte${title(var.environment)}01"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_db_instance" "airbyte" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  db_instance_identifier = local.airbyte_rds_identifier
}

# ---------------------------------------------------------------------------
# dbt ECS data source — gated on enable_dbt_ecs_monitoring
# ---------------------------------------------------------------------------

data "aws_ecs_cluster" "dbt" {
  count        = var.create && var.enable_dbt_ecs_monitoring ? 1 : 0
  cluster_name = "Reg20DBT${title(var.environment)}01"
}

# ---------------------------------------------------------------------------
# IAM policy document for the SNS KMS key — allows CloudWatch Alarms to publish
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "sns_kms_key" {
  count = var.create ? 1 : 0

  statement {
    sid    = "EnableRootAccountAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchAlarmsToUseKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowSNSServiceToUseKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    resources = ["*"]
  }
}
