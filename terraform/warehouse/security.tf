resource "aws_security_group" "redshift" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to the Redshift Serverless workgroup in redshift.tf
  count = var.create ? 1 : 0

  name        = "${local.name}-redshift"
  description = "Controls SQL access to the Redshift Serverless workgroup"
  vpc_id      = data.aws_vpc.this[0].id

  ingress {
    description = "Redshift SQL from VPC CIDR"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this[0].cidr_block]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "redshift_from_bastion" {
  count = var.create ? 1 : 0

  security_group_id            = aws_security_group.redshift[0].id
  description                  = "Redshift SQL from bastion host, dbt Cloud tunnel"
  ip_protocol                  = "tcp"
  from_port                    = 5439
  to_port                      = 5439
  referenced_security_group_id = aws_security_group.bastion[0].id
}

resource "aws_vpc_security_group_egress_rule" "redshift_https_vpc" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.redshift[0].id
  description       = "HTTPS to VPC CIDR (interface endpoints)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.this[0].cidr_block
}

resource "aws_vpc_security_group_egress_rule" "redshift_sql_vpc" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.redshift[0].id
  description       = "Redshift SQL to VPC CIDR (intra-VPC traffic)"
  ip_protocol       = "tcp"
  from_port         = 5439
  to_port           = 5439
  cidr_ipv4         = data.aws_vpc.this[0].cidr_block
}

resource "aws_vpc_security_group_egress_rule" "redshift_s3_gateway" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.redshift[0].id
  description       = "HTTPS to S3 gateway endpoint prefix list"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = data.aws_vpc_endpoint.s3[0].prefix_list_id
}

# Bastion security group — ingress restricted to dbt Cloud static IPs only.
resource "aws_security_group" "bastion" {
  #checkov:skip=CKV2_AWS_5: SG is attached to the bastion EC2 instance in bastion.tf
  count = var.create ? 1 : 0

  name        = "${local.name}-bastion"
  description = "Controls SSH access to the bastion host from dbt Cloud IPs"
  vpc_id      = data.aws_vpc.this[0].id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_dbt" {
  for_each = var.create ? toset(local.dbt_cloud_ips) : []

  security_group_id = aws_security_group.bastion[0].id
  description       = "SSH from dbt Cloud"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${each.key}/32"
}

resource "aws_vpc_security_group_egress_rule" "bastion_redshift" {
  count = var.create ? 1 : 0

  security_group_id            = aws_security_group.bastion[0].id
  description                  = "Redshift SQL to Redshift SG (SSH tunnel forwarding)"
  ip_protocol                  = "tcp"
  from_port                    = 5439
  to_port                      = 5439
  referenced_security_group_id = aws_security_group.redshift[0].id
}

resource "aws_vpc_security_group_egress_rule" "bastion_https_vpc" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[0].id
  description       = "HTTPS to VPC CIDR (SSM and CloudWatch endpoints)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.this[0].cidr_block
}
