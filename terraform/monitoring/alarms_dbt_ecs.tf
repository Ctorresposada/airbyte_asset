resource "aws_cloudwatch_metric_alarm" "dbt_ecs_cpu" {
  count = var.create && var.enable_dbt_ecs_monitoring ? 1 : 0

  alarm_name          = "${local.name}-dbt-ecs-cpu"
  alarm_description   = "dbt ECS cluster CPU utilization exceeded 80% for 15 minutes — transformation runs are taking longer than expected; increase the task definition CPU allocation"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 900
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "Reg20DBT${title(var.environment)}01"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-dbt-ecs-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "dbt_ecs_memory" {
  count = var.create && var.enable_dbt_ecs_monitoring ? 1 : 0

  alarm_name          = "${local.name}-dbt-ecs-memory"
  alarm_description   = "dbt ECS cluster memory utilization exceeded 80% for 15 minutes — container is at risk of being stopped mid-run by Fargate OOM protection; increase task definition memory"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 900
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = "Reg20DBT${title(var.environment)}01"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-dbt-ecs-memory"
  }
}

# ---------------------------------------------------------------------------
# dbt task failure — EventBridge rule on ECS task stopped with non-zero exit code
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "dbt_task_failure" {
  count = var.create && var.enable_dbt_ecs_monitoring ? 1 : 0

  name        = "${local.name}-dbt-task-failure"
  description = "Fires when a dbt ECS task stops with a non-zero exit code indicating a failed transformation run"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [data.aws_ecs_cluster.dbt[0].arn]
      lastStatus = ["STOPPED"]
      containers = {
        exitCode = [{ anything-but = [0] }]
      }
    }
  })

  tags = {
    Name = "${local.name}-dbt-task-failure"
  }
}

resource "aws_cloudwatch_event_target" "dbt_task_failure_sns" {
  count = var.create && var.enable_dbt_ecs_monitoring ? 1 : 0

  rule = aws_cloudwatch_event_rule.dbt_task_failure[0].name
  arn  = aws_sns_topic.critical[0].arn
}

# The SNS topic policy that allows EventBridge to publish to the critical topic
# lives in sns.tf (aws_sns_topic_policy.critical_eventbridge). It is shared by
# every EventBridge rule that targets the critical topic — the dbt task-failure
# rule here and the Glue crawler-failure rules in alarms_glue.tf — because a
# single SNS topic can have only one topic policy.
