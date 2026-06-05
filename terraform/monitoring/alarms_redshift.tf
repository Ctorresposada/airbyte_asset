resource "aws_cloudwatch_metric_alarm" "redshift_active_queries" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-redshift-active-queries"
  alarm_description   = "More than 50 queries running concurrently in Redshift for 15 minutes"
  namespace           = "AWS/Redshift-Serverless"
  metric_name         = "QueriesRunning"
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkgroupName = "${local.name}-warehouse-wg"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-redshift-active-queries"
  }
}

resource "aws_cloudwatch_metric_alarm" "redshift_query_failures" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-redshift-query-failures"
  alarm_description   = "5 or more Redshift query failures in 10 minutes — reports may be returning errors"
  namespace           = "AWS/Redshift-Serverless"
  metric_name         = "QueryFailed"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkgroupName = "${local.name}-warehouse-wg"
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-redshift-query-failures"
  }
}

resource "aws_cloudwatch_metric_alarm" "redshift_connection_limit" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-redshift-connection-limit"
  alarm_description   = "More than 200 active Redshift connections for 15 minutes — connection pool may be exhausted"
  namespace           = "AWS/Redshift-Serverless"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 200
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkgroupName = "${local.name}-warehouse-wg"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-redshift-connection-limit"
  }
}

resource "aws_cloudwatch_metric_alarm" "redshift_compute_usage" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-redshift-compute-usage"
  alarm_description   = "Redshift hourly ComputeSeconds sum exceeds threshold — potential runaway query or unexpected cost spike"
  namespace           = "AWS/Redshift-Serverless"
  metric_name         = "ComputeSeconds"
  statistic           = "Sum"
  period              = 3600
  evaluation_periods  = 1
  threshold           = var.redshift_compute_seconds_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WorkgroupName = "${local.name}-warehouse-wg"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-redshift-compute-usage"
  }
}
