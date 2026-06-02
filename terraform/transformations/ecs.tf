# ---------------------------------------------------------------------------
# ECS cluster — Fargate-only, Container Insights enabled for task/cluster metrics.
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  #checkov:skip=CKV_AWS_224: ECS Exec logging is encrypted — cloud_watch_encryption_enabled = true on a CMK-encrypted log group (aws_cloudwatch_log_group.cluster). Checkov does not detect the CW-log-group CMK path; encryption is in place.
  count = var.create ? 1 : 0

  name = local.compute_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.cluster[0].name
      }
    }
  }

  tags = merge(var.tags, {
    Name = local.compute_name
  })
}

# Capacity providers: FARGATE (on-demand) and FARGATE_SPOT (cost-optimized).
# Default strategy runs tasks on FARGATE; dbt jobs can opt into SPOT at run time.
resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.create ? 1 : 0

  cluster_name       = aws_ecs_cluster.this[0].name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }
}

# ---------------------------------------------------------------------------
# Task definition — single dbt Core container. Terraform creates the initial
# revision with a static placeholder image; the dbt build pipeline takes over
# from there, registering new revisions with immutable build tags via AWS CLI.
# container_definitions is ignored on subsequent applies (see lifecycle block).
# dbt reads source data from S3/Glue via Redshift Spectrum external schemas and
# never connects to Redshift directly, so the only environment the container
# needs is the S3 artifacts bucket and the AWS region.
# ---------------------------------------------------------------------------
resource "aws_ecs_task_definition" "dbt_core" {
  count = var.create && var.enable_dbt_task ? 1 : 0

  family                   = "${local.name}-dbt-core"
  cpu                      = var.dbt_task_cpu
  memory                   = var.dbt_task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.dbt_execution[0].arn
  task_role_arn            = aws_iam_role.dbt_task[0].arn

  container_definitions = jsonencode([
    {
      name      = "dbt-core"
      image     = "${var.ecr_repository_url}:initial"
      essential = true

      # All non-secret. dbt reads source data from S3/Glue via Redshift Spectrum
      # external schemas, so only the artifacts bucket and region are needed.
      environment = [
        { name = "DBT_ARTIFACTS_BUCKET", value = aws_s3_bucket.dbt_artifacts[0].id },
        { name = "AWS_REGION", value = var.aws_region },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dbt_core[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "dbt-core"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-core"
  })

  lifecycle {
    ignore_changes = [container_definitions]
  }
}
