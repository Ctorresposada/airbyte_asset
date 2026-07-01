# Module: airbyte-eks
# Self-hosted Airbyte on EKS via Helm. All durable state is externalized:
# RDS PostgreSQL (config + Temporal), S3 (logs/artifacts), and Secrets Manager
# (connector credentials). Airbyte is installed via the official Helm chart.
# IRSA replaces the EC2 instance profile for AWS API access from pods.

locals {
  name_prefix = var.name

  common_tags = merge(var.tags, {
    Module = "airbyte-eks"
    Name   = var.name
  })

  # Resolve the certificate ARN: use the provided one, or the one created by this module.
  effective_certificate_arn = var.alb_certificate_arn != "" ? var.alb_certificate_arn : try(aws_acm_certificate.this[0].arn, "")

  # Resolve the Airbyte URL from domain_name if provided.
  airbyte_url = var.domain_name != "" ? "https://${var.domain_name}" : ""

  # Whether to create DNS and certificate resources.
  create_dns = var.domain_name != "" && var.route53_zone_id != ""
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# ---------------------------------------------------------------------------
# KMS -- Customer-managed key for all Airbyte resources
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms" {
  # Allow the account root full key management.
  statement {
    sid    = "AllowRootAccount"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow the Auto Scaling service-linked role to use this key for encrypted
  # EBS volumes. EKS managed node groups use the same ASG SLR under the hood.
  # Split into two statements per AWS docs: crypto operations have no condition (the
  # kms:GrantIsForAWSResource context key is only present during CreateGrant calls, so
  # combining them in one statement silently denies Encrypt/Decrypt/GenerateDataKey*).
  statement {
    sid    = "AllowAutoScalingServiceRoleKMS"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAutoScalingServiceRoleGrant"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # Allow CloudWatch Logs to use the key for log group encryption.
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/airbyte/${var.name}"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "CMK for Airbyte resources (${var.name})"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json

  tags = local.common_tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

# ---------------------------------------------------------------------------
# Random password for RDS
# ---------------------------------------------------------------------------

resource "random_password" "rds" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------------------------
# Secrets Manager -- RDS credentials
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds" {
  #checkov:skip=CKV2_AWS_57: Automatic rotation requires a Lambda rotator and coordinated Airbyte restart; rotation is performed manually during maintenance windows
  name                    = "${var.name}/rds"
  description             = "RDS credentials for Airbyte PostgreSQL (${var.name})"
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.rds.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.rds_db_name
  })
}

# ---------------------------------------------------------------------------
# Secrets Manager -- Airbyte web UI admin credentials
# ---------------------------------------------------------------------------

# Placeholder secret; the Airbyte Helm chart generates admin credentials in a
# Kubernetes secret (airbyte-auth-secrets). A post-deploy job or manual step
# copies those credentials here so operators have a single source of truth.
resource "aws_secretsmanager_secret" "airbyte_admin" {
  #checkov:skip=CKV2_AWS_57: Automatic rotation requires a Lambda rotator and coordinated Airbyte restart; rotation is performed manually during maintenance windows
  name                    = "${var.name}/airbyte-admin-creds"
  description             = "Airbyte web UI admin credentials (${var.name}). Populated after first Helm deploy."
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = 0

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to aws_db_instance.this via vpc_security_group_ids; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-rds"
  description = "Allow PostgreSQL ingress from Airbyte EKS nodes only"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from Airbyte EKS nodes"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.node_group.id

  tags = local.common_tags
}

# Node group security group. EKS also attaches its own managed cluster SG.
# This SG carries the application-level rules: ALB -> pods and nodes -> RDS.
resource "aws_security_group" "node_group" {
  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to the EKS node group via launch template; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-nodes"
  description = "Controls traffic to and from Airbyte EKS nodes for ${var.name}."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nodes" })

  lifecycle {
    create_before_destroy = true
  }
}

# Node-to-node communication (required for pod scheduling and CNI).
resource "aws_vpc_security_group_ingress_rule" "nodes_self" {
  security_group_id            = aws_security_group.node_group.id
  description                  = "Allow all traffic between nodes in the same group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.node_group.id

  tags = local.common_tags
}

# ALB -> pods: ALB controller uses target-type=ip so traffic arrives directly
# at pod IPs from within the VPC. Allow port 8080 (Airbyte webapp) from VPC.
resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  #checkov:skip=CKV_AWS_260: Ingress is bounded to the VPC CIDR, not 0.0.0.0/0
  security_group_id = aws_security_group.node_group.id
  description       = "Airbyte webapp traffic from ALB (target-type: ip, VPC CIDR)"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.this.cidr_block

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "nodes_all_out" {
  security_group_id = aws_security_group.node_group.id
  description       = "Allow all outbound traffic - Airbyte connectors reach arbitrary external sources and destinations"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# RDS -- DB subnet group and PostgreSQL instance
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name        = var.name
  description = "Subnet group for Airbyte RDS PostgreSQL (${var.name})"
  subnet_ids  = var.private_subnet_ids

  tags = local.common_tags
}

resource "aws_db_instance" "this" {
  identifier            = var.name
  engine                = "postgres"
  engine_version        = "16"
  instance_class        = var.rds_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.this.arn

  db_name  = var.rds_db_name
  username = var.rds_username
  password = random_password.rds.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.rds_multi_az

  backup_retention_period = var.rds_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${var.name}-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring.arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.this.arn
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = false
  copy_tags_to_snapshot      = true

  tags = local.common_tags

  #checkov:skip=CKV_AWS_157: Multi-AZ is configurable via var.rds_multi_az; default true for EKS HA deployments
  #checkov:skip=CKV_AWS_133: Deletion protection configurable via var.rds_deletion_protection
  #checkov:skip=CKV_AWS_293: Deletion protection is governed by var.rds_deletion_protection; callers enable it for production
  #checkov:skip=CKV_AWS_161: Airbyte does not support IAM authentication for its internal PostgreSQL config database
  #checkov:skip=CKV2_AWS_30: Query logging on Airbyte internal config DB generates excessive volume with no security benefit; application logs exported via enabled_cloudwatch_logs_exports
  #checkov:skip=CKV2_AWS_60: copy_tags_to_snapshot is set to true; checkov may not resolve the attribute correctly
}

# ---------------------------------------------------------------------------
# S3 -- Airbyte logs and artifacts bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.s3_force_destroy

  tags = local.common_tags

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for Airbyte log/artifact storage
  #checkov:skip=CKV2_AWS_62: S3 event notifications not required
  #checkov:skip=CKV_AWS_18: S3 access logging deferred to calling stack
  #checkov:skip=CKV2_AWS_6: False positive -- public access block enforced via aws_s3_bucket_public_access_block.this
  #checkov:skip=CKV_AWS_21: False positive -- versioning enabled via aws_s3_bucket_versioning.this
  #checkov:skip=CKV2_AWS_61: False positive -- lifecycle configuration enforced via aws_s3_bucket_lifecycle_configuration.this
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = 90
    }
  }

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# CloudWatch log group
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = "/airbyte/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this.arn

  tags = local.common_tags
}
