# Transformations stack CMK
# Encrypts: dbt artifacts S3 bucket (SSE-KMS), dbt service-account secret in
# Secrets Manager, and the dbt CloudWatch log groups (cluster + ECS task).
# The CloudWatch Logs service principal is granted use of the key, scoped via an
# encryption-context condition to this stack's log-group ARNs only.

module "transformations_kms" {
  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description             = "CMK for dbt transformations data (S3 artifacts, dbt secret, CloudWatch Logs) — ${local.name}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 14

  aliases = ["${local.name}-transformations"]

  key_users = var.kms_key_users

  key_statements = [
    {
      sid    = "AllowCloudWatchLogsUseOfKey"
      effect = "Allow"
      actions = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*",
      ]
      resources = ["*"]
      principals = [
        {
          type        = "Service"
          identifiers = ["logs.${var.aws_region}.amazonaws.com"]
        }
      ]
      conditions = [
        {
          test     = "ArnLike"
          variable = "kms:EncryptionContext:aws:logs:arn"
          values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/ecs/${local.name}-dbt-core*"]
        }
      ]
    },
  ]
}
