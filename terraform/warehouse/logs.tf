locals {
  redshift_log_exports = ["userlog", "connectionlog", "useractivitylog"]
}

resource "aws_cloudwatch_log_group" "redshift" {
  #checkov:skip=CKV_AWS_338: Retention is environment-driven via var.redshift_log_retention_days. Dev keeps 30 days to control CloudWatch storage cost; prod sets >= 365.
  for_each = var.create ? toset(local.redshift_log_exports) : []

  name              = "/aws/redshift/${local.name}-warehouse/${each.key}"
  retention_in_days = var.redshift_log_retention_days
  kms_key_id        = module.redshift_kms[0].key_arn
}
