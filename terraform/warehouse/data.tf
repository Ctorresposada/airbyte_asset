data "aws_vpc" "this" {
  count = var.create ? 1 : 0

  tags = {
    Name = local.name
  }
}

data "aws_subnets" "private" {
  count = var.create ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  tags = {
    Tier = "private-app"
  }
}

data "aws_security_group" "client_vpn" {
  count = var.create && var.vpn_enabled ? 1 : 0

  vpc_id = data.aws_vpc.this[0].id

  tags = {
    Name = "${local.name}-client-vpn"
  }
}

data "aws_vpc_endpoint" "s3" {
  count = var.create ? 1 : 0

  vpc_id       = data.aws_vpc.this[0].id
  service_name = "com.amazonaws.${var.aws_region}.s3"
}

data "aws_subnets" "public" {
  count = var.create && var.enable_bastion ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this[0].id]
  }

  tags = {
    Tier = "public"
  }
}

data "aws_ami" "al2023" {
  count = var.create && var.enable_bastion ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

