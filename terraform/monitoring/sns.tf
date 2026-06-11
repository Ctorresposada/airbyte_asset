# ---------------------------------------------------------------------------
# CMK for SNS topic encryption — CloudWatch Alarms require explicit key policy
# permission to publish to encrypted SNS topics.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "sns" {
  count = var.create ? 1 : 0

  description             = "${local.name}-monitoring SNS encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sns_kms_key[0].json

  tags = {
    Name = "${local.name}-monitoring-sns-key"
  }
}

resource "aws_kms_alias" "sns" {
  count = var.create ? 1 : 0

  name          = "alias/${local.name}-monitoring-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

# ---------------------------------------------------------------------------
# Warning SNS topic
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "warning" {
  count = var.create ? 1 : 0

  name              = "${local.name}-monitoring-warning"
  kms_master_key_id = aws_kms_key.sns[0].arn

  tags = {
    Name = "${local.name}-monitoring-warning"
  }
}

resource "aws_sns_topic_subscription" "warning_email" {
  count = var.create ? length(var.warning_emails) : 0

  topic_arn = aws_sns_topic.warning[0].arn
  protocol  = "email"
  endpoint  = var.warning_emails[count.index]
}

# ---------------------------------------------------------------------------
# Critical SNS topic
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "critical" {
  count = var.create ? 1 : 0

  name              = "${local.name}-monitoring-critical"
  kms_master_key_id = aws_kms_key.sns[0].arn

  tags = {
    Name = "${local.name}-monitoring-critical"
  }
}

resource "aws_sns_topic_subscription" "critical_email" {
  count = var.create ? length(var.critical_emails) : 0

  topic_arn = aws_sns_topic.critical[0].arn
  protocol  = "email"
  endpoint  = var.critical_emails[count.index]
}

# ---------------------------------------------------------------------------
# Critical topic policy — allows EventBridge to publish.
#
# Shared by every EventBridge rule that targets the critical topic (Glue
# crawler failures in alarms_glue.tf, dbt task failures in alarms_dbt_ecs.tf).
# A single SNS topic can have only one topic policy, so it lives here and is
# gated only on var.create — not on any per-feature flag — so the policy is
# always present whenever a rule that needs it could exist. EventBridge calls
# SNS:Publish; SNS itself (sns.amazonaws.com, already granted in the SNS KMS
# key policy in data.tf) performs the at-rest encryption, so no additional KMS
# grant for events.amazonaws.com is required.
# ---------------------------------------------------------------------------

# Critical topic policy — allows EventBridge rules AND the Airbyte webhook Lambda
# to publish. A single SNS topic may have only one topic policy, so both
# principals are consolidated here. The policy is gated only on var.create so
# it is always present when any rule or Lambda that needs it could exist.
resource "aws_sns_topic_policy" "critical_eventbridge" {
  count = var.create ? 1 : 0

  arn = aws_sns_topic.critical[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowEventBridgePublish"
          Effect = "Allow"
          Principal = {
            Service = "events.amazonaws.com"
          }
          Action   = "SNS:Publish"
          Resource = aws_sns_topic.critical[0].arn
        },
      ],
      local.enable_webhook ? [
        {
          Sid    = "AllowWebhookLambdaPublish"
          Effect = "Allow"
          Principal = {
            AWS = try(aws_iam_role.airbyte_webhook[0].arn, "")
          }
          Action   = "SNS:Publish"
          Resource = aws_sns_topic.critical[0].arn
        },
      ] : []
    )
  })
}

# Warning topic policy — allows the Airbyte webhook Lambda to publish.
# The warning topic had no resource policy prior to this addition; EventBridge
# does not target the warning topic so no Service principal is needed here.
resource "aws_sns_topic_policy" "warning_webhook" {
  count = local.enable_webhook ? 1 : 0

  arn = aws_sns_topic.warning[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWebhookLambdaPublish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.airbyte_webhook[0].arn
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.warning[0].arn
      },
    ]
  })
}
