# ---------------------------------------------------------------------------
# AMI: latest Amazon Linux 2023 x86_64 resolved via SSM Parameter Store
# ---------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023_ami" {
  count = var.create ? 1 : 0

  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# ---------------------------------------------------------------------------
# Networking: look up shared VPC and private-app subnets by tag
# ---------------------------------------------------------------------------
data "aws_vpc" "this" {
  count = var.create ? 1 : 0

  tags = { Name = local.name }
}

data "aws_subnets" "private" {
  count = var.create ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  tags = { Tier = "private-app" }
}

data "aws_subnets" "public" {
  count = var.create ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  tags = { Tier = "public" }
}

# ---------------------------------------------------------------------------
# KMS key policy document
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "airbyte_kms" {
  #checkov:skip=CKV_AWS_111: Allow account usage of key, default policy 
  #checkov:skip=CKV_AWS_356: Allow account usage of key, default policy
  #checkov:skip=CKV_AWS_109: Allow account usage of key, default policy

  count = var.create ? 1 : 0

  # Root account retains full key administration
  statement {
    sid       = "AllowRootAccountFullAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  # EC2 Auto Scaling service-linked role needs explicit key access for EBS encryption.
  # Root account delegation does not cover service-linked roles for this use case.
  # Ref: https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html
  statement {
    sid    = "AllowASGServiceLinkedRoleUseOfKey"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
  }

  statement {
    sid       = "AllowASGServiceLinkedRoleCreateGrant"
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
  }

  # CloudWatch Logs needs Encrypt/Decrypt to write to the Airbyte log group
  statement {
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

    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/airbyte/${local.name}-airbyte"]
    }
  }
}

# ---------------------------------------------------------------------------
# KMS key: dedicated CMK for all Airbyte-owned resources
# ---------------------------------------------------------------------------
resource "aws_kms_key" "airbyte" {
  count = var.create ? 1 : 0

  description             = "CMK for Airbyte compute resources -- ${local.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 14

  policy = data.aws_iam_policy_document.airbyte_kms[0].json

  tags = { Name = "${local.name}-airbyte" }
}

resource "aws_kms_alias" "airbyte" {
  count = var.create ? 1 : 0

  name          = "alias/${local.name}-airbyte"
  target_key_id = aws_kms_key.airbyte[0].key_id
}

# ---------------------------------------------------------------------------
# Airbyte compute module
# ---------------------------------------------------------------------------
module "airbyte" {
  count  = var.create ? 1 : 0
  source = "../modules/airbyte"

  name               = "${local.name}-airbyte"
  compute_name       = local.compute_name
  vpc_id             = data.aws_vpc.this[0].id
  private_subnet_ids = data.aws_subnets.private[0].ids
  ami_id             = data.aws_ssm_parameter.al2023_ami[0].value
  kms_key_arn        = aws_kms_key.airbyte[0].arn

  instance_type           = var.airbyte_instance_type
  rds_instance_class      = var.airbyte_rds_instance_class
  rds_db_name             = "airbyte"
  log_retention_days      = var.airbyte_log_retention_days
  rds_multi_az            = var.airbyte_rds_multi_az
  rds_skip_final_snapshot = var.airbyte_rds_skip_final_snapshot
  rds_deletion_protection = var.airbyte_rds_deletion_protection
  s3_force_destroy        = var.airbyte_s3_force_destroy

  create_alb          = true
  alb_internal        = false
  alb_subnet_ids      = data.aws_subnets.public[0].ids
  alb_certificate_arn = aws_acm_certificate_validation.airbyte[0].certificate_arn

  allowed_cidr_blocks = var.airbyte_alb_allowed_cidr_blocks

  airbyte_url = "https://${var.environment == "prod" ? "airbyte" : "airbyte-${var.environment}"}.esc20.net"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Client VPN SG lookup -- resolved when vpn_available = true
# ---------------------------------------------------------------------------
data "aws_security_groups" "client_vpn" {
  count = var.create && var.vpn_available ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  filter {
    name   = "group-name"
    values = ["${local.name}-client-vpn-*"]
  }
}

# ---------------------------------------------------------------------------
# Airbyte instance ingress from Client VPN (SG-to-SG, not CIDR-based)
# ---------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "airbyte_instance_from_vpn_ui" {
  count = var.create && var.vpn_available ? 1 : 0

  security_group_id            = module.airbyte[0].instance_sg_id
  description                  = "Airbyte UI direct access from Client VPN on port 8000"
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_groups.client_vpn[0].ids[0]

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "airbyte_instance_to_oci" {
  count = var.create ? 1 : 0

  security_group_id = module.airbyte[0].instance_sg_id
  description       = "Airbyte access to OCI bastion"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.oci_bastion_host

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Route53: hosted zone data source (lives in account 332872251707)
# ---------------------------------------------------------------------------
data "aws_route53_zone" "esc_net" {
  count = var.create ? 1 : 0

  provider = aws.route53
  name     = "esc20.net"
}

# ---------------------------------------------------------------------------
# ACM: public certificate with DNS validation
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "airbyte" {
  #checkov:skip=CKV2_AWS_71: Ensure AWS ACM Certificate domain name does not include wildcards

  count = var.create ? 1 : 0

  domain_name       = "*.esc20.net"
  validation_method = "DNS"

  tags = merge(var.tags, { Name = "${local.name}-airbyte" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "airbyte_cert_validation" {
  count = var.create ? 1 : 0

  provider = aws.route53
  zone_id  = data.aws_route53_zone.esc_net[0].zone_id
  name     = one(aws_acm_certificate.airbyte[0].domain_validation_options).resource_record_name
  type     = one(aws_acm_certificate.airbyte[0].domain_validation_options).resource_record_type
  records  = [one(aws_acm_certificate.airbyte[0].domain_validation_options).resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "airbyte" {
  count = var.create ? 1 : 0

  certificate_arn         = aws_acm_certificate.airbyte[0].arn
  validation_record_fqdns = [aws_route53_record.airbyte_cert_validation[0].fqdn]
}

# ---------------------------------------------------------------------------
# Route53: A alias record pointing to the public ALB
# ---------------------------------------------------------------------------
resource "aws_route53_record" "airbyte" {
  count = var.create ? 1 : 0

  provider = aws.route53
  zone_id  = data.aws_route53_zone.esc_net[0].zone_id
  name     = var.environment == "prod" ? "airbyte" : "airbyte-${var.environment}"
  type     = "A"

  alias {
    name                   = module.airbyte[0].alb_dns_name
    zone_id                = module.airbyte[0].alb_zone_id
    evaluate_target_health = true
  }
}
