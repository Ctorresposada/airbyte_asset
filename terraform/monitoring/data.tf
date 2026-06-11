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
# VPC and execute-api endpoint — looked up for the private API Gateway
# ---------------------------------------------------------------------------

data "aws_vpc" "this" {
  count = local.enable_webhook ? 1 : 0

  tags = {
    Name = local.name
  }
}

data "aws_vpc_endpoint" "execute_api" {
  count = local.enable_webhook ? 1 : 0

  vpc_id       = data.aws_vpc.this[0].id
  service_name = "com.amazonaws.${var.aws_region}.execute-api"
}

# ---------------------------------------------------------------------------
# IAM policy document for the SNS KMS key — allows CloudWatch Alarms to publish
# and grants the webhook Lambda and CloudWatch Logs access for the encrypted
# Lambda log group.
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

  # CloudWatch Logs needs the full action set to write encrypted log events.
  # The region-specific principal and EncryptionContext condition are both
  # mandated by AWS for CMK-backed log groups.
  statement {
    sid    = "AllowCloudWatchLogsToUseKey"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.this.account_id}:*"]
    }
  }

  # The Lambda execution role needs GenerateDataKey + Decrypt to publish to the
  # KMS-encrypted SNS topics. Guarded by enable_webhook so the role reference is
  # never evaluated when the webhook resources are not created.
  dynamic "statement" {
    for_each = local.enable_webhook ? [1] : []
    content {
      sid    = "AllowWebhookLambdaToUseKey"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.airbyte_webhook[0].arn]
      }

      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey*",
      ]

      resources = ["*"]
    }
  }
}
