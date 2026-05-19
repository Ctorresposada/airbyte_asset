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
}
