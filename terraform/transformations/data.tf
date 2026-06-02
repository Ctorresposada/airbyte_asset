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
