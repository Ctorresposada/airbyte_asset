# Security group for the dbt Core Fargate tasks. Fargate tasks are outbound-only:
# no ingress rules. Egress allows all outbound so dbt can reach S3, ECR, CloudWatch
# Logs, and Redshift Serverless (port 5439) via the catch-all rule below.
resource "aws_security_group" "dbt_ecs" {
  #checkov:skip=CKV2_AWS_5: SG is attached to the dbt Core ECS task definition's network configuration in ecs.tf.
  count = var.create ? 1 : 0

  name        = "${local.name}-dbt-core-ecs"
  description = "Outbound-only SG for dbt Core Fargate tasks (S3, ECR, Logs)"
  vpc_id      = data.aws_vpc.this[0].id

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-core-ecs"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "dbt_ecs_all" {
  #checkov:skip=CKV_AWS_382: dbt tasks require unrestricted HTTPS egress — S3, ECR, and CloudWatch are reached over multiple endpoints; egress is the only direction open and ingress is fully closed.
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.dbt_ecs[0].id
  description       = "Allow all outbound from dbt Core Fargate tasks"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Ingress rule on the warehouse Redshift SG — allows dbt Core ECS tasks to reach
# Redshift Serverless on port 5439. Placed here (not in the warehouse stack) to
# avoid a cross-stack circular lookup dependency.
resource "aws_vpc_security_group_ingress_rule" "redshift_from_dbt_ecs" {
  count = var.create ? 1 : 0

  security_group_id            = data.aws_security_group.redshift[0].id
  description                  = "Redshift SQL from dbt Core ECS tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5439
  to_port                      = 5439
  referenced_security_group_id = aws_security_group.dbt_ecs[0].id
}
