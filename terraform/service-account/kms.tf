# Service-account CMK
# Encrypts the shared dbt Core ECR repository (SSE-KMS). Because the repository
# is pulled cross-account by the dev and prod workload accounts, those account
# roots are granted kms:Decrypt on this key. ECR does NOT transparently broker
# KMS decrypt for cross-account pulls the way it does the ECR API authorization,
# so the consuming principals must be able to decrypt against this CMK directly.

module "service_account_kms" {
  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description             = "CMK for the shared dbt Core ECR repository - ${local.name}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 14

  aliases = ["${local.name}-ecr"]

  key_statements = [
    {
      sid    = "AllowConsumerAccountsDecrypt"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      resources = ["*"]
      principals = [
        {
          type        = "AWS"
          identifiers = [for id in var.consumer_account_ids : "arn:aws:iam::${id}:root"]
        }
      ]
    },
  ]
}
