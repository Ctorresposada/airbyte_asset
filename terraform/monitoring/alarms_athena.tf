resource "aws_cloudwatch_metric_alarm" "athena_slow_queries" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-athena-slow-queries"
  alarm_description   = "Athena p99 query execution time exceeds 5 minutes — likely missing partitions or data growth"
  namespace           = "AWS/Athena"
  metric_name         = "ProcessingTime"
  extended_statistic  = "p99"
  period              = 300
  evaluation_periods  = 1
  threshold           = 300000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-athena-slow-queries"
  }
}

resource "aws_cloudwatch_metric_alarm" "athena_cost_control" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-athena-cost-control"
  alarm_description   = "Athena scanned more than 100 GB today — unpartitioned table scan or runaway query may be driving unexpected cost"
  namespace           = "AWS/Athena"
  metric_name         = "ProcessedBytes"
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 107374182400
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-athena-cost-control"
  }
}

# Athena does not write query logs to CloudWatch Logs, so failed queries cannot be
# counted with a log metric filter. Instead, Athena publishes a native per-query
# metric in the AWS/Athena namespace dimensioned by WorkGroup and QueryState. Each
# failed query produces one datapoint, so SampleCount of any per-query metric scoped
# to QueryState=FAILED equals the number of failed queries in the period.
# TotalExecutionTime is emitted for both DDL and DML queries, making it the most
# complete metric to count against. The metric only emits on failure, so missing
# data is treated as not breaching.
resource "aws_cloudwatch_metric_alarm" "athena_failed_queries" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-athena-failed-queries"
  alarm_description   = "5 or more Athena query failures in 10 minutes — schema change or missing data file likely"
  namespace           = "AWS/Athena"
  metric_name         = "TotalExecutionTime"
  statistic           = "SampleCount"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkGroup  = "primary"
    QueryState = "FAILED"
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-athena-failed-queries"
  }
}
