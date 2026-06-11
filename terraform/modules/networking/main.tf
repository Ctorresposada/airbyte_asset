# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  create_igw = true

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    Tier = "public"
  }

  private_subnet_tags = {
    Tier = "private-app"
  }
}

# ---------------------------------------------------------------------------
# Security group for interface VPC endpoints
# ---------------------------------------------------------------------------

resource "aws_security_group" "interface_endpoints" {
  #checkov:skip=CKV_AWS_260: Egress to 0.0.0.0/0 required - interface endpoint responses are not CIDR-predictable
  #checkov:skip=CKV_AWS_382: Same rationale as CKV_AWS_260 - egress to all ports/all destinations required for interface endpoint responses
  #checkov:skip=CKV2_AWS_5: SG is attached to all interface VPC endpoints via security_group_ids in the module.endpoints call below

  name_prefix = "${var.name}-interface-endpoints-"
  description = "Allow HTTPS from VPC CIDR to interface VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------------------------
# Interface VPC endpoints
# ---------------------------------------------------------------------------

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    secretsmanager = {
      service             = "secretsmanager"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    glue = {
      service             = "glue"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    states = {
      service             = "states"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    redshift = {
      service             = "redshift"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    kms = {
      service             = "kms"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    execute_api = {
      service             = "execute-api"
      service_type        = "Interface"
      subnet_ids          = module.vpc.private_subnets
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.interface_endpoints.id]
    }
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)
      tags            = { Name = "${var.name}-s3-gateway" }
    }
  }
}

# ---------------------------------------------------------------------------
# VPC Flow Log resource — delivers to the centralized audit-account bucket
# ---------------------------------------------------------------------------

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = module.vpc.vpc_id
  traffic_type             = var.flow_log_traffic_type
  log_destination_type     = "s3"
  log_destination          = var.flow_log_bucket_arn
  max_aggregation_interval = 600

  destination_options {
    file_format                = var.flow_log_file_format
    hive_compatible_partitions = var.flow_log_hive_compatible_partitions
    per_hour_partition         = var.flow_log_per_hour_partition
  }
}
