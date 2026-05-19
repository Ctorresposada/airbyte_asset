# R2EP2IC-31 — Redshift Serverless namespace + workgroup for the GOLD data layer.
# Encrypted with the warehouse stack CMK, private subnets only, no public access,
# Redshift-managed admin password stored in Secrets Manager.

resource "aws_redshiftserverless_namespace" "this" {
  count = var.create ? 1 : 0

  namespace_name       = "${local.name}-warehouse"
  db_name              = var.redshift_db_name
  kms_key_id           = module.redshift_kms[0].key_arn
  iam_roles            = [aws_iam_role.redshift_serverless[0].arn]
  default_iam_role_arn = aws_iam_role.redshift_serverless[0].arn

  admin_username        = var.redshift_admin_username
  manage_admin_password = true

  log_exports = ["userlog", "connectionlog", "useractivitylog"]
}

resource "aws_redshiftserverless_workgroup" "this" {
  count = var.create ? 1 : 0

  namespace_name = aws_redshiftserverless_namespace.this[0].namespace_name
  workgroup_name = "${local.name}-warehouse-wg"

  base_capacity        = var.redshift_base_capacity
  max_capacity         = var.redshift_max_capacity
  enhanced_vpc_routing = true
  publicly_accessible  = false

  subnet_ids         = data.aws_subnets.private[0].ids
  security_group_ids = [aws_security_group.redshift[0].id]
}
