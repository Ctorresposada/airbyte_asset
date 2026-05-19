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
