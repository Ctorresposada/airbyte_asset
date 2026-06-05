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
