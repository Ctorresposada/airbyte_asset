# ---------------------------------------------------------------------------
# EventBridge Scheduler — daily dbt pipeline (bronze → silver → gold)
#
# How it works:
#   1. EventBridge Scheduler fires at the configured cron time.
#   2. It assumes the dbt_scheduler IAM role (below) to call ecs:RunTask.
#   3. ECS launches a new Fargate task using the dbt_core task definition.
#   4. The container runs the dbt pipeline in a single invocation:
#      bronze models first, then silver, then gold — all in sequence.
#   5. If any layer fails the container exits non-zero and the task stops;
#      the monitoring stack's dbt_task_failure EventBridge rule catches it
#      and sends an alert to SNS. No auto-retry is configured here (see below).
#
# Gating: all three resources below share the same count condition so they
# are created and destroyed atomically. The schedule only exists when:
#   - var.create = true           (stack is enabled)
#   - var.enable_dbt_task = true  (ECS task definition exists)
#   - var.enable_dbt_schedule = true  (scheduling is explicitly turned on)
# ---------------------------------------------------------------------------

# IAM role that EventBridge Scheduler assumes when it fires.
# The scheduler service needs two permissions at task launch time:
#   ecs:RunTask  — to start the Fargate task on the cluster.
#   iam:PassRole — to hand both the execution role (image pull / log stream)
#                  and the task role (runtime AWS access) to the ECS agent.
#                  Without PassRole the RunTask call is rejected by IAM even
#                  though the scheduler role holds ecs:RunTask.
resource "aws_iam_role" "dbt_scheduler" {
  count = var.create && var.enable_dbt_task && var.enable_dbt_schedule ? 1 : 0

  name = "${local.name}-dbt-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-scheduler"
  })
}

data "aws_iam_policy_document" "dbt_scheduler" {
  count = var.create && var.enable_dbt_task && var.enable_dbt_schedule ? 1 : 0

  # Scoped to all revisions of the dbt-core task definition family.
  # We use a wildcard on the revision number because CI registers new revisions
  # out-of-band (e.g. :46, :47) and the scheduler always targets the latest one
  # via arn_without_revision — the IAM resource must cover those future revisions.
  statement {
    sid     = "EcsRunTask"
    effect  = "Allow"
    actions = ["ecs:RunTask"]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.account_id}:task-definition/${local.name}-dbt-core:*",
    ]
  }

  # iam:PassRole does not support resource-level conditions natively, but
  # the iam:PassedToService condition key restricts pass to ECS tasks only —
  # the scheduler role cannot be abused to pass roles to other services.
  statement {
    sid     = "PassRoleToEcs"
    effect  = "Allow"
    actions = ["iam:PassRole"]

    resources = [
      aws_iam_role.dbt_execution[0].arn, # needed by ECS agent: image pull + log stream
      aws_iam_role.dbt_task[0].arn,      # needed by the container: S3, Athena, Redshift, etc.
    ]

    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "dbt_scheduler" {
  count = var.create && var.enable_dbt_task && var.enable_dbt_schedule ? 1 : 0

  name   = "${local.name}-dbt-scheduler-inline"
  role   = aws_iam_role.dbt_scheduler[0].id
  policy = data.aws_iam_policy_document.dbt_scheduler[0].json
}

# ---------------------------------------------------------------------------
# The schedule itself.
#
# target.arn uses the EventBridge Scheduler AWS SDK integration for ECS RunTask
# ("arn:aws:scheduler:::aws-sdk:ecs:runTask"). This lets us pass the full
# RunTask API payload (cluster, task def, network config) as structured JSON
# rather than constructing a CloudWatch Events ECS target — cleaner and gives
# us full control over the launch parameters.
#
# flexible_time_window mode = "OFF" means the task fires at exactly the cron
# time. A flexible window would let EventBridge drift the start time to smooth
# load across many schedules — not useful for a pipeline with strict ordering.
#
# retry_policy.maximum_retry_attempts = 0: auto-retry is intentionally disabled.
# A dbt failure mid-run (e.g. bronze succeeds, silver fails) leaves the silver
# layer in a partial state. Blindly rerunning the full pipeline on top of that
# can compound the inconsistency. Operators should investigate, fix the root
# cause, and trigger a manual run. The monitoring stack alerts on any non-zero
# exit so failures are never silent.
# ---------------------------------------------------------------------------
resource "aws_scheduler_schedule" "dbt_pipeline" {
  count = var.create && var.enable_dbt_task && var.enable_dbt_schedule ? 1 : 0

  name       = "${local.name}-dbt-pipeline"
  group_name = "default"

  # Cron and timezone are driven by tfvars per environment so dev and prod
  # can run at different times without touching this file.
  schedule_expression          = var.dbt_schedule_expression
  schedule_expression_timezone = var.dbt_schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:runTask"
    role_arn = aws_iam_role.dbt_scheduler[0].arn

    # RunTask payload — keys are PascalCase to match the AWS SDK/API contract.
    # Subnets and SecurityGroups are sourced from data lookups so this file
    # does not need to hard-code any IDs.
    input = jsonencode({
      Cluster = aws_ecs_cluster.this[0].arn

      # arn_without_revision tells ECS to always launch the latest ACTIVE revision
      # of the task definition family. CI registers new revisions after every image
      # push (e.g. :46, :47 ...) — using the revision-pinned ARN would silently run
      # a stale image and miss those CI-built updates.
      TaskDefinition = aws_ecs_task_definition.dbt_core[0].arn_without_revision

      # Capacity provider strategy instead of LaunchType — the two are mutually
      # exclusive in the RunTask API. FARGATE_SPOT reduces cost in dev by ~70%;
      # prod uses on-demand FARGATE to avoid Spot interruptions mid-run.
      CapacityProviderStrategy = [
        {
          CapacityProvider = var.dbt_capacity_provider
          Weight           = 1
          Base             = 0
        }
      ]

      NetworkConfiguration = {
        AwsvpcConfiguration = {
          Subnets        = data.aws_subnets.private[0].ids # private-app subnets from networking stack
          SecurityGroups = [aws_security_group.dbt_ecs[0].id]
          AssignPublicIp = "DISABLED" # tasks run in private subnets, NAT handles egress / Public IP turnned off
        }
      }

      # Command override — replaces the container's default CMD at runtime.
      # dbt deps installs packages (packages.yml) before running models.
      # The three dbt run calls execute layers in order: bronze → silver → gold.
      # If any layer fails the shell exits non-zero and halts the chain — silver
      # never runs on top of incomplete bronze data, and so on downstream.
      Overrides = {
        ContainerOverrides = [
          {
            Name    = "dbt-core"
            Command = var.dbt_schedule_command
          }
        ]
      }
    })

    retry_policy {
      maximum_retry_attempts       = 0    # no auto-retry — see note above
      maximum_event_age_in_seconds = 3600 # drop the event if ECS is unavailable for >1h
    }
  }
}
