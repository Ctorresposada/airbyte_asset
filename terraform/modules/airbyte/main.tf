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
    Module = "airbyte-compute"
    Name   = var.name
  })

  # SSM parameter name for the rendered Helm values file.
  ssm_parameter_name = "/${var.name}/airbyte/values"

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
  })

  # Rendered user-data bootstrap script.
  # try() guards the log group reference so locals evaluate cleanly when
  # var.create = false and the count-0 resource does not exist.
  user_data_content = templatefile("${path.module}/templates/user-data.sh.tpl", {
    ssm_parameter_name = local.ssm_parameter_name
    aws_region         = data.aws_region.current.region
    abctl_version      = local.abctl_version
    log_group_name     = try(aws_cloudwatch_log_group.this[0].name, "")
  })
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Random password for RDS
# ---------------------------------------------------------------------------

resource "random_password" "rds" {
  count = var.create ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
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

  name               = "${local.name_prefix}-airbyte-instance-role"
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
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [try("${aws_s3_bucket.this[0].arn}/*", "arn:aws:s3:::placeholder-never-used/*")]
  }

  statement {
    sid    = "AirbyteS3Bucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [try(aws_s3_bucket.this[0].arn, "arn:aws:s3:::placeholder-never-used")]
  }

  # Secrets Manager: allow Airbyte to read connector credentials it stores
  # under the airbyte/ prefix.
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
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "this" {
  count = var.create ? 1 : 0

  name   = "${local.name_prefix}-airbyte-inline"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.airbyte_inline.json
}

resource "aws_iam_instance_profile" "this" {
  count = var.create ? 1 : 0

  name = "${local.name_prefix}-airbyte-instance-profile"
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
  kms_key_id              = var.kms_key_arn
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
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to aws_db_instance.this via vpc_security_group_ids; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-rds"
  description = "Allow PostgreSQL ingress from Airbyte EC2 instances only"
  vpc_id      = var.vpc_id
  # No egress rules are attached. The AWS default allow-all egress rule applies,
  # but RDS has no route to any destination outside the VPC by design.
  # The subnet routing table and NACLs enforce the actual egress boundary.

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

  name        = "${local.name_prefix}-airbyte-alb"
  description = "Controls inbound HTTPS/HTTP to the Airbyte internal ALB from ${var.name} allowed CIDRs."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-airbyte-alb" })

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
  description                  = "HTTP egress to Airbyte instance on port 80"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.instance[0].id

  tags = local.common_tags
}

resource "aws_security_group" "instance" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_5: False positive -- this SG is attached to aws_launch_template.this via vpc_security_group_ids; checkov cannot follow the cross-resource reference
  name        = "${local.name_prefix}-airbyte-instance"
  description = "Controls traffic to and from the Airbyte EC2 instance for ${var.name}."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-airbyte-instance" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_from_alb" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  #checkov:skip=CKV_AWS_260: False positive -- ingress is restricted to the ALB security group via referenced_security_group_id, not from 0.0.0.0/0
  security_group_id            = aws_security_group.instance[0].id
  description                  = "HTTP ingress from ALB only"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb[0].id

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "instance_https_out" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.instance[0].id
  description       = "HTTPS egress for Docker Hub pulls, GitHub releases, AWS API calls not covered by VPC endpoints"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "instance_to_rds" {
  count = var.create ? 1 : 0

  security_group_id            = aws_security_group.instance[0].id
  description                  = "PostgreSQL egress to RDS security group"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds[0].id

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
  kms_key_id            = var.kms_key_arn

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
  performance_insights_kms_key_id       = var.kms_key_arn
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

  bucket        = "${var.name}-airbyte"
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
      kms_master_key_id = var.kms_key_arn
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
    id     = "abort-incomplete-mpu"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# SSM Parameter -- Helm values delivery
# ---------------------------------------------------------------------------

resource "aws_ssm_parameter" "airbyte_values" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV_AWS_337: SecureString is encrypted with var.kms_key_arn (CMK); checkov may flag if it cannot resolve the type attribute
  name        = local.ssm_parameter_name
  description = "Rendered Airbyte Helm values YAML for ${var.name}. Pulled by user-data at instance boot."
  type        = "SecureString"
  key_id      = var.kms_key_arn
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
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Launch template
# ---------------------------------------------------------------------------

resource "aws_launch_template" "this" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV_AWS_88: Instances are in private subnets; associate_public_ip_address is false by subnet design
  name_prefix = "${local.name_prefix}-airbyte-"
  description = "Launch template for self-hosted Airbyte running abctl on ${var.name}"

  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.this[0].arn
  }

  vpc_security_group_ids = [aws_security_group.instance[0].id]

  user_data = base64encode(local.user_data_content)

  # IMDSv2 required -- prevents SSRF-based metadata access.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Detailed CloudWatch monitoring.
  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-airbyte" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-airbyte-root" })
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

  #checkov:skip=CKV_AWS_150: Deletion protection is intentionally omitted; module is used for dev/staging as well as prod. Enable at the stack level for prod if required.
  #checkov:skip=CKV2_AWS_28: WAF association is managed outside this module; internal ALB is not public-facing
  #checkov:skip=CKV_AWS_91: ALB access logging requires a dedicated S3 bucket; intentionally deferred to the calling stack
  name                       = "${local.name_prefix}-airbyte"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = var.alb_subnet_ids
  drop_invalid_header_fields = true

  enable_deletion_protection = false

  tags = local.common_tags
}

resource "aws_lb_target_group" "this" {
  count = var.create ? (var.create_alb ? 1 : 0) : 0

  name        = "${local.name_prefix}-airbyte"
  port        = 80
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

  #checkov:skip=CKV_AWS_2: HTTPS is configured via var.alb_certificate_arn; checkov may misread the forward action
  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  tags = local.common_tags
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

  name                = "${local.name_prefix}-airbyte"
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
    value               = "${local.name_prefix}-airbyte"
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

  # create_before_destroy omitted: meaningless for a singleton ASG; instance_refresh handles replacement.
  lifecycle {
    # Prevent Terraform from resetting desired_capacity if it was manually
    # adjusted during a blue/green upgrade window.
    ignore_changes = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_iam_role_policy.this,
    aws_ssm_parameter.airbyte_values,
  ]
}
