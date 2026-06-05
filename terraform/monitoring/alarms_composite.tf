# The composite alarm rule is built by joining individual alarm ARNs with OR.
# The Airbyte DB storage alarm is included conditionally when enable_airbyte_monitoring = true.
# compact() drops null entries produced by the conditional so the join is always valid.

locals {
  pipeline_health_alarm_rule = join(" OR ", compact([
    var.create ? "ALARM(\"${aws_cloudwatch_metric_alarm.lambda_sync_errors[0].alarm_name}\")" : null,
    var.create ? "ALARM(\"${aws_cloudwatch_metric_alarm.glue_connect20_failure[0].alarm_name}\")" : null,
    var.create ? "ALARM(\"${aws_cloudwatch_metric_alarm.redshift_query_failures[0].alarm_name}\")" : null,
    var.create && var.enable_airbyte_monitoring ? "ALARM(\"${aws_cloudwatch_metric_alarm.airbyte_db_storage[0].alarm_name}\")" : null,
  ]))
}

resource "aws_cloudwatch_composite_alarm" "pipeline_health" {
  count = var.create ? 1 : 0

  alarm_name        = "${local.name}-pipeline-health"
  alarm_description = "At least one critical data pipeline component is in ALARM state. Check individual component alarms to identify the affected service."
  alarm_rule        = local.pipeline_health_alarm_rule

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-pipeline-health"
  }

  depends_on = [
    aws_cloudwatch_metric_alarm.lambda_sync_errors,
    aws_cloudwatch_metric_alarm.glue_connect20_failure,
    aws_cloudwatch_metric_alarm.redshift_query_failures,
    aws_cloudwatch_metric_alarm.airbyte_db_storage,
  ]
}
