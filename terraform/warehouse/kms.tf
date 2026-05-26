# Redshift data CMK — R2EP2IC-106
# Used by Redshift namespace for encryption at rest.


module "redshift_kms" {
  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description             = "CMK for Redshift data encryption at rest — ${local.name}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 14

  aliases = ["${local.name}-redshift"]

  key_users = var.redshift_key_users

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
          values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/redshift/${local.name}-warehouse/*"]
        }
      ]
    },
  ]
}

# Bastion secrets + CloudWatch Logs CMK — R2EP2IC-111
# Encrypts: bastion private key in Secrets Manager, bastion EBS root volume, bastion CW log groups.
module "bastion_kms" {
  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description             = "CMK for bastion EC2 EBS volume and CloudWatch Logs -- ${local.name}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 14

  aliases = ["${local.name}-bastion"]

  # IAM role gets Decrypt/GenerateDataKey via its inline policy — no key_users here
  # to keep the CMK key policy minimal and auditable.
  key_users = []

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
          values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/ec2/${local.name}-bastion/*"]
        }
      ]
    },
  ]
}
