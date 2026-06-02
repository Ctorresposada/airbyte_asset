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
# Task definition — single dbt Core container. The image tag is resolved from the
# live task definition at plan time (see local.dbt_image), so CI-managed build tags
# registered out-of-band via AWS CLI are never overwritten by Terraform, while env
# var and other container changes still apply normally.
# dbt uses the Athena adapter to run transformations on S3 data, so the container
# needs the artifacts, Athena results, and silver buckets plus the AWS region.
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
      image     = local.dbt_image
      essential = true

      # All non-secret. dbt uses the Athena adapter: it writes query results to the
      # Athena results bucket and reads silver-layer source data from the silver
      # bucket, alongside its own artifacts bucket and the AWS region.
      environment = [
        { name = "DBT_ARTIFACTS_BUCKET", value = aws_s3_bucket.dbt_artifacts[0].id },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "ATHENA_RESULTS_BUCKET", value = data.aws_s3_bucket.athena_results[0].id },
        { name = "SILVER_BUCKET", value = data.aws_s3_bucket.silver[0].id },
        { name = "REDSHIFT_HOST", value = data.aws_redshiftserverless_workgroup.this[0].endpoint[0].address },
        { name = "REDSHIFT_PORT", value = "5439" },
        { name = "REDSHIFT_DB", value = var.redshift_db },
        { name = "REDSHIFT_SCHEMA", value = var.redshift_schema },
        { name = "REDSHIFT_USER", value = var.redshift_user },
        { name = "REDSHIFT_WORKGROUP_NAME", value = local.warehouse_wg_name },
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
}
