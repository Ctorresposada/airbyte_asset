# Module: airbyte-ec2
# Self-hosted Airbyte on EC2 Auto Scaling Group using abctl (kind-in-Docker).
# All durable state is externalized: RDS PostgreSQL (config + Temporal), S3
# (logs/artifacts), and Secrets Manager (connector credentials). The kind
# cluster holds no persistent data; ASG replacement rebuilds it from scratch.

locals {
  # abctl version is pinned here; not exposed as a variable to prevent
  # accidental drift between the binary and the checksums file.
  abctl_version = "v0.30.4"

  name_prefix = var.name

  common_tags = merge(var.tags, {
    Module = "airbyte"
    Name   = var.name
  })

  # SSM parameter name for the rendered Helm values file.
  ssm_parameter_name = "/${var.name}/airbyte/values"

  # Resolve the certificate ARN: use the provided one, or the one created by this module.
  effective_certificate_arn = var.alb_certificate_arn != "" ? var.alb_certificate_arn : try(aws_acm_certificate.this[0].arn, "")

  # Resolve the Airbyte URL from domain_name if provided.
  airbyte_url = var.domain_name != "" ? "https://${var.domain_name}" : ""

  # Whether to create DNS and certificate resources.
  create_dns = var.create && var.create_alb && var.domain_name != "" && var.route53_zone_id != ""

  # Rendered Helm values YAML, interpolating all internal-dependency
  # coordinates. Every key path is verified against tmp.yaml (chart v2.1.0).
  # try() guards count-0 references so locals evaluate cleanly when create=false.
  airbyte_values_content = templatefile("${path.module}/templates/airbyte-values.yaml.tpl", {
    db_host     = try(aws_db_instance.this[0].address, "")
    db_port     = try(aws_db_instance.this[0].port, 5432)
    db_name     = var.rds_db_name
    db_user     = var.rds_username
    db_password = try(random_password.rds[0].result, "")

    temporal_db_host     = try(aws_db_instance.this[0].address, "")
    temporal_db_port     = try(aws_db_instance.this[0].port, 5432)
    temporal_db_name     = var.rds_temporal_db_name
    temporal_db_user     = var.rds_username
    temporal_db_password = try(random_password.rds[0].result, "")

    s3_bucket_name = try(aws_s3_bucket.this[0].id, "")
    s3_region      = data.aws_region.current.region
    aws_region     = data.aws_region.current.region
    airbyte_url    = local.airbyte_url
  })

  # Rendered user-data bootstrap script.
  # try() guards the log group reference so locals evaluate cleanly when
  # var.create = false and the count-0 resource does not exist.
  user_data_content = templatefile("${path.module}/templates/user-data.sh.tpl", {
    ssm_parameter_name = local.ssm_parameter_name
    aws_region         = data.aws_region.current.region
    abctl_version      = local.abctl_version
    log_group_name     = try(aws_cloudwatch_log_group.this[0].name, "")
    db_host            = try(aws_db_instance.this[0].address, "")
    db_port            = try(aws_db_instance.this[0].port, 5432)
    db_user            = var.rds_username
    db_name            = var.rds_db_name
    rds_secret_arn     = try(aws_secretsmanager_secret.rds[0].arn, "")

    airbyte_admin_secret_arn = try(aws_secretsmanager_secret.airbyte_admin[0].arn, "")
  })
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# KMS -- Customer-managed key for all Airbyte resources
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms" {
  count = var.create ? 1 : 0

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

  # Allow the Auto Scaling service-linked role to use this key for encrypted EBS volumes.
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
  count = var.create ? 1 : 0

  description             = "CMK for Airbyte resources (${var.name})"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms[0].json

  tags = local.common_tags
}

resource "aws_kms_alias" "this" {
  count = var.create ? 1 : 0

  name          = "alias/${replace(var.name, ".", "-")}"
  target_key_id = aws_kms_key.this[0].key_id
}

# KMS grants take a few seconds to propagate before EC2 can use the key for
# EBS encryption. Without this delay the ASG launch fails with
# InvalidKMSKey.InvalidState on first deploy.
resource "time_sleep" "kms_propagation" {
  count = var.create ? 1 : 0

  create_duration = "15s"
  depends_on      = [aws_kms_key.this, aws_kms_alias.this]
}

# ---------------------------------------------------------------------------
# Random password for RDS
# ---------------------------------------------------------------------------

resource "random_password" "rds" {
  count = var.create ? 1 : 0

  length  = 32
  special = true
  # Restricted to characters safe in YAML (avoids anchor &, alias *, tag !, flow {}/[]),
  # Helm strvals (avoids , separator), and shell (avoids glob *, redirection <>, subshell ()).
  override_special = "#$%-_=+@"
}

# ---------------------------------------------------------------------------
# IAM -- EC2 instance role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create ? 1 : 0

  name               = "${local.name_prefix}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "airbyte_inline" {
  # S3 access for Airbyte logs, state payloads, and workload output.
  statement {
    sid    = "AirbyteS3Objects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObjectAcl",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation"
    ]
    resources = [
      try("${aws_s3_bucket.this[0].arn}/*", "arn:aws:s3:::placeholder-never-used/*"),
      try(aws_s3_bucket.this[0].arn, "arn:aws:s3:::placeholder-never-used/*")
    ]
  }

  statement {
    sid    = "AirbyteS3Bucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [try(aws_s3_bucket.this[0].arn, "arn:aws:s3:::placeholder-never-used")]
  }

  # Secrets Manager: allow Airbyte to manage connector credentials it stores
  # under the airbyte/ prefix. ListSecrets requires resource "*" per the IAM
  # API — it cannot be scoped to specific ARNs. Airbyte uses it to discover
  # and enumerate connector secrets at startup.
  statement {
    sid    = "AirbyteSecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:TagResource",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:airbyte/*",
      try(aws_secretsmanager_secret.rds[0].arn, "arn:aws:secretsmanager:::secret:placeholder"),
      try(aws_secretsmanager_secret.airbyte_admin[0].arn, "arn:aws:secretsmanager:::secret:placeholder-admin"),
    ]
  }

  # SSM: read the rendered values file at boot.
  statement {
    sid    = "AirbyteSsmValues"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_parameter_name}",
    ]
  }

  # KMS: decrypt SSM SecureString, EBS volumes, and CloudWatch log group.
  statement {
    sid    = "AirbyteKms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [try(aws_kms_key.this[0].arn, "arn:aws:kms:::key/placeholder")]
  }
}

resource "aws_iam_role_policy" "this" {
  count = var.create ? 1 : 0

  name   = "${local.name_prefix}-inline"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.airbyte_inline.json
}

resource "aws_iam_instance_profile" "this" {
  count = var.create ? 1 : 0

  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.this[0].name

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# IAM -- RDS enhanced monitoring role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.create ? 1 : 0

  name               = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# Secrets Manager -- RDS credentials
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_57: Automatic rotation requires a Lambda rotator and coordinated Airbyte restart; rotation is performed manually during maintenance windows
  name                    = "${var.name}/rds"
  description             = "RDS credentials for Airbyte PostgreSQL (${var.name})"
  kms_key_id              = aws_kms_key.this[0].arn
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds" {
  count = var.create ? 1 : 0

  secret_id = aws_secretsmanager_secret.rds[0].id
  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.rds[0].result
    host     = aws_db_instance.this[0].address
    port     = aws_db_instance.this[0].port
    dbname   = var.rds_db_name
  })
}

# ---------------------------------------------------------------------------
# Secrets Manager -- Airbyte web UI admin credentials
# ---------------------------------------------------------------------------

# Holds the Airbyte web UI admin username/password. The value is populated at
# instance boot by user-data, which extracts the generated credentials from the
# abctl Kubernetes auth secret and pushes them here via put-secret-value.
resource "aws_secretsmanager_secret" "airbyte_admin" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_57: Automatic rotation requires a Lambda rotator and coordinated Airbyte restart; rotation is performed manually during maintenance windows
  name                    = "${var.name}/airbyte-admin-creds"
  description             = "Airbyte web UI admin credentials (${var.name})"
  kms_key_id              = aws_kms_key.this[0].arn
  recovery_window_in_days = 7

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to aws_db_instance.this via vpc_security_group_ids; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-rds"
  description = "Allow PostgreSQL ingress from Airbyte EC2 instances only"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

# Ingress and deny-egress rules declared as standalone resources to avoid a
# circular dependency between aws_security_group.rds and aws_security_group.instance.
resource "aws_vpc_security_group_ingress_rule" "rds_from_instance" {
  count = var.create ? 1 : 0

  security_group_id            = aws_security_group.rds[0].id
  description                  = "PostgreSQL from Airbyte instances"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.instance[0].id

  tags = local.common_tags
}

resource "aws_security_group" "alb" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  name        = "${local.name_prefix}-alb"
  description = "Controls inbound HTTPS/HTTP to the Airbyte ALB from allowed CIDRs."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = var.create ? (var.create_alb ? length(var.allowed_cidr_blocks) : 0) : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTPS ingress from allowed CIDR"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_cidr_blocks[count.index]

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count = var.create ? (var.create_alb ? length(var.allowed_cidr_blocks) : 0) : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "HTTP ingress from allowed CIDR (redirected to HTTPS by listener)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_cidr_blocks[count.index]

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_instance" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  security_group_id            = aws_security_group.alb[0].id
  description                  = "HTTP egress to Airbyte nginx on port 8000"
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.instance[0].id

  tags = local.common_tags
}

resource "aws_security_group" "instance" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to aws_launch_template.this via vpc_security_group_ids; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-instance"
  description = "Controls traffic to and from the Airbyte EC2 instance for ${var.name}."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-instance" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_from_alb" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  #checkov:skip=CKV_AWS_260: False positive -- ingress is restricted to the ALB security group via referenced_security_group_id, not from 0.0.0.0/0
  security_group_id            = aws_security_group.instance[0].id
  description                  = "HTTP ingress from ALB on port 8000"
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb[0].id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "instance_all_out" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.instance[0].id
  description       = "Allow all outbound traffic - Airbyte connectors reach arbitrary external sources and destinations"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# RDS -- DB subnet group and PostgreSQL instance
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  count = var.create ? 1 : 0

  name        = var.name
  description = "Subnet group for Airbyte RDS PostgreSQL (${var.name})"
  subnet_ids  = var.private_subnet_ids

  tags = local.common_tags
}

resource "aws_db_instance" "this" {
  count = var.create ? 1 : 0

  identifier            = var.name
  engine                = "postgres"
  engine_version        = "16"
  instance_class        = var.rds_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.this[0].arn

  db_name  = var.rds_db_name
  username = var.rds_username
  password = random_password.rds[0].result

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
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
  monitoring_role_arn             = aws_iam_role.rds_enhanced_monitoring[0].arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.this[0].arn
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = false
  copy_tags_to_snapshot      = true

  tags = local.common_tags

  #checkov:skip=CKV_AWS_157: Multi-AZ is configurable via var.rds_multi_az; default off for cost optimization
  #checkov:skip=CKV_AWS_133: Deletion protection configurable via var.rds_deletion_protection
  #checkov:skip=CKV_AWS_293: Deletion protection is governed by var.rds_deletion_protection; callers enable it for production
  #checkov:skip=CKV_AWS_161: Airbyte does not support IAM authentication for its internal PostgreSQL config database
  #checkov:skip=CKV2_AWS_30: Query logging on Airbyte internal config DB generates excessive volume with no security benefit; application logs exported via enabled_cloudwatch_logs_exports
  #checkov:skip=CKV2_AWS_60: copy_tags_to_snapshot is set to true below; checkov may not resolve the attribute from the count-indexed resource
}

# ---------------------------------------------------------------------------
# S3 -- Airbyte logs and artifacts bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  count = var.create ? 1 : 0

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
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create ? 1 : 0

  bucket                  = aws_s3_bucket.this[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "s3_ssl_only" {
  count = var.create ? 1 : 0

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[0].arn,
      "${aws_s3_bucket.this[0].arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.this[0].id
  policy = data.aws_iam_policy_document.s3_ssl_only[0].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.this[0].id

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
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
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
# ACM Certificate -- created when domain_name is provided
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  allow_overwrite = true
  name            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.this[0].domain_validation_options)[0].resource_record_type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count = local.create_dns && var.alb_certificate_arn == "" ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
}

# ---------------------------------------------------------------------------
# Route53 -- A record pointing to the ALB
# ---------------------------------------------------------------------------

resource "aws_route53_record" "airbyte" {
  count = local.create_dns ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this[0].dns_name
    zone_id                = aws_lb.this[0].zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------
# SSM Parameter -- Helm values delivery
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "airbyte_values" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV_AWS_337: SecureString is encrypted with CMK; checkov may flag if it cannot resolve the type attribute
  name        = local.ssm_parameter_name
  description = "Rendered Airbyte Helm values YAML for ${var.name}. Pulled by user-data at instance boot."
  type        = "SecureString"
  key_id      = aws_kms_key.this[0].arn
  value       = local.airbyte_values_content
  tier        = "Advanced" # values file exceeds 4 KB Standard tier limit

  tags = local.common_tags

  # SSM parameter updates are applied immediately by Terraform. They do NOT
  # trigger an ASG instance refresh -- only launch template version changes do.
  # To push new values to a running instance, trigger a manual instance refresh.
  depends_on = [
    aws_db_instance.this,
    aws_s3_bucket.this,
  ]
}

# ---------------------------------------------------------------------------
# CloudWatch log group
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  count = var.create ? 1 : 0

  name              = "/airbyte/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.this[0].arn

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Launch template
# ---------------------------------------------------------------------------

resource "aws_launch_template" "this" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV_AWS_88: Instances are in private subnets; associate_public_ip_address is false by subnet design
  #checkov:skip=CKV_AWS_341: hop_limit > 1 required for Docker/kind containers running inside the instance to reach IMDS
  name_prefix = "${local.name_prefix}-"
  description = "Launch template for self-hosted Airbyte running abctl on ${var.name}"

  depends_on = [time_sleep.kms_propagation]

  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.this[0].arn
  }

  vpc_security_group_ids = [aws_security_group.instance[0].id]

  user_data = base64encode(local.user_data_content)

  # IMDSv2 required -- prevents SSRF-based metadata access.
  # hop_limit=3 is required for kind-in-Docker: traffic traverses two extra network
  # hops (Docker bridge + kind container network) before reaching IMDS. The EKS
  # module uses hop_limit=2 because pods are only one hop from the node.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 3
  }

  # Detailed CloudWatch monitoring.
  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.ebs_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.this[0].arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.common_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-root" })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  #checkov:skip=CKV2_AWS_28: WAF association is managed outside this module
  name                       = local.name_prefix
  internal                   = var.alb_internal
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = var.alb_subnet_ids
  drop_invalid_header_fields = true

  enable_deletion_protection = var.alb_deletion_protection

  dynamic "access_logs" {
    for_each = var.alb_access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "this" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  name        = local.name_prefix
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200-399"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "https" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  #checkov:skip=CKV_AWS_2: HTTPS is configured via certificate_arn; checkov may misread the forward action
  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.effective_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  tags = local.common_tags

  depends_on = [aws_acm_certificate_validation.this]
}

resource "aws_lb_listener" "http" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Auto Scaling Group
# ---------------------------------------------------------------------------

resource "aws_autoscaling_group" "this" {
  count = var.create ? 1 : 0

  name                = local.name_prefix
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.private_subnet_ids

  target_group_arns = try([aws_lb_target_group.this[0].arn], [])

  # Use EC2 health checks when no ALB target group is attached.
  health_check_type         = var.create_alb ? "ELB" : "EC2"
  health_check_grace_period = 900 # abctl install including Docker pull and image pulls takes 7-12 minutes

  launch_template {
    id      = aws_launch_template.this[0].id
    version = "$Latest"
  }

  # Single-instance ASG; min_healthy_percentage=0 allows the refresh to
  # terminate the existing instance before launching the replacement.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    # Ignore desired_capacity so Terraform does not reset the ASG size after
    # manual scaling or auto-scaling events between applies.
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_iam_role_policy.this,
    aws_ssm_parameter.airbyte_values,
  ]
}
