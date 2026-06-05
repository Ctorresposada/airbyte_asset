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

# Failed queries alarm uses the custom metric emitted by the log metric filter in log_metric_filters.tf
resource "aws_cloudwatch_metric_alarm" "athena_failed_queries" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-athena-failed-queries"
  alarm_description   = "5 or more Athena query failures in 10 minutes — schema change or missing data file likely"
  namespace           = "Region20/Athena"
  metric_name         = "FailedQueries"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-athena-failed-queries"
  }
}
