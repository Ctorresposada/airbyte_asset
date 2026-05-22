# ---------------------------------------------------------------------------
# Secrets Manager secret — holds the SAML metadata XML from IAM Identity Center.
# Created on first apply (var.create only); user populates the real value via
# the AWS console or CLI before setting enable_client_vpn = true.
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "client_vpn_saml" {
  count = var.create ? 1 : 0

  #checkov:skip=CKV2_AWS_57: Rotation not applicable; this secret holds a static IdP metadata document that is rotated manually via IAM Identity Center
  #checkov:skip=CKV_AWS_149: KMS encryption is optional for this non-sensitive public IdP metadata document; controlled via client_vpn_log_kms_key_arn

  name                    = "${local.name}/client-vpn/saml-metadata-document"
  description             = "SAML metadata XML exported from the IAM Identity Center Client VPN application. Populate this secret before setting enable_client_vpn = true."
  recovery_window_in_days = 0
  kms_key_id              = var.client_vpn_log_kms_key_arn != "" ? var.client_vpn_log_kms_key_arn : null
}

# ---------------------------------------------------------------------------
# Read the current secret value when the VPN endpoint is being provisioned
# ---------------------------------------------------------------------------

data "aws_secretsmanager_secret_version" "client_vpn_saml" {
  count = var.create && var.enable_client_vpn ? 1 : 0

  secret_id = aws_secretsmanager_secret.client_vpn_saml[0].id
}

# ---------------------------------------------------------------------------
# IAM SAML identity provider for IDC-federated Client VPN authentication
# ---------------------------------------------------------------------------

resource "aws_iam_saml_provider" "client_vpn" {
  count = var.create && var.enable_client_vpn ? 1 : 0

  name                   = "${local.name}-client-vpn-idp"
  saml_metadata_document = data.aws_secretsmanager_secret_version.client_vpn_saml[0].secret_string
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group for VPN connection logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "client_vpn" {
  #checkov:skip=CKV_AWS_338: Retention set to 90 days

  count = var.create && var.enable_client_vpn ? 1 : 0

  name              = "/aws/client-vpn/${local.name}"
  retention_in_days = var.client_vpn_log_retention_days
  kms_key_id        = var.client_vpn_log_kms_key_arn != "" ? var.client_vpn_log_kms_key_arn : null
}

# ---------------------------------------------------------------------------
# Security group for the Client VPN endpoint
# ---------------------------------------------------------------------------

resource "aws_security_group" "client_vpn" {
  count = var.create && var.enable_client_vpn ? 1 : 0

  #checkov:skip=CKV_AWS_260: Outbound access to private subnets required for VPN tunnel traffic; no unrestricted internet egress
  #checkov:skip=CKV_AWS_382: Egress must allow all ports so that authenticated VPN clients can reach arbitrary services in the VPC
  #checkov:skip=CKV2_AWS_5: SG is attached to the aws_ec2_client_vpn_endpoint resource below

  name_prefix = "${local.name}-client-vpn-"
  description = "Allow inbound UDP 443 (OpenVPN) to the Client VPN endpoint from the internet; restrict egress to the VPC CIDR"
  vpc_id      = module.networking[0].vpc_id

  ingress {
    description = "OpenVPN from anywhere (auth is enforced by IDC SAML before a session is established)"
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow VPN clients to reach all resources inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
}

# ---------------------------------------------------------------------------
# Client VPN endpoint — SAML federated, split-tunnel, DNS-enabled
# ---------------------------------------------------------------------------

resource "aws_ec2_client_vpn_endpoint" "this" {
  count = var.create && var.enable_client_vpn ? 1 : 0

  description            = "${local.name} developer/analyst Client VPN"
  server_certificate_arn = var.client_vpn_server_certificate_arn
  client_cidr_block      = var.client_vpn_client_cidr
  split_tunnel           = true
  vpc_id                 = module.networking[0].vpc_id
  security_group_ids     = [aws_security_group.client_vpn[0].id]

  # IDC SAML federated authentication — no client certs required
  authentication_options {
    type              = "federated-authentication"
    saml_provider_arn = aws_iam_saml_provider.client_vpn[0].arn
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group = aws_cloudwatch_log_group.client_vpn[0].name
  }

  dns_servers = [
    # VPC resolver: second IP of the VPC CIDR (e.g. 172.17.0.2 for 172.17.0.0/16)
    cidrhost(var.vpc_cidr, 2),
  ]
}

# ---------------------------------------------------------------------------
# Network associations — one per private subnet so VPN traffic egresses
# through the subnet's local ENI and hits the NAT/private route tables
# ---------------------------------------------------------------------------

resource "aws_ec2_client_vpn_network_association" "private" {
  for_each = var.create && var.enable_client_vpn ? toset(module.networking[0].private_subnet_ids) : toset([])

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  subnet_id              = each.value
}

# ---------------------------------------------------------------------------
# Authorization rule — all authenticated users may reach the full VPC CIDR.
# Access is already gated at the IDC layer; no per-group ACL is needed here.
# ---------------------------------------------------------------------------

resource "aws_ec2_client_vpn_authorization_rule" "vpc_cidr" {
  count = var.create && var.enable_client_vpn ? 1 : 0

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this[0].id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
  description            = "Allow all IDC-authenticated VPN users to reach the full VPC CIDR"

  timeouts {
    create = "20m"
    delete = "20m"
  }
}

