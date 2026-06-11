resource "aws_cloudwatch_metric_alarm" "airbyte_db_cpu" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-rds-cpu"
  alarm_description   = "Airbyte RDS CPU utilization exceeded 80% for 15 minutes — may slow sync orchestration; consider scaling to a larger instance class"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 900
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-rds-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_db_storage" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-rds-storage"
  alarm_description   = "Airbyte RDS free storage dropped below 5 GB — Airbyte will stop recording sync state; increase allocated storage via the AWS console (no downtime required)"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 5368709120
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-airbyte-rds-storage"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_db_connections" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-rds-connections"
  alarm_description   = "Airbyte RDS connection count exceeded 100 for 15 minutes — possible connection leak or abnormal number of Airbyte workers"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 100
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-rds-connections"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_db_read_latency" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-rds-read-latency"
  alarm_description   = "Airbyte RDS p99 read latency exceeded 50 ms — Airbyte UI and scheduler response may be degraded"
  namespace           = "AWS/RDS"
  metric_name         = "ReadLatency"
  extended_statistic  = "p99"
  period              = 900
  evaluation_periods  = 1
  threshold           = 0.05
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-rds-read-latency"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_db_write_latency" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-rds-write-latency"
  alarm_description   = "Airbyte RDS p99 write latency exceeded 50 ms — sync jobs may appear stuck while Airbyte waits to record job state"
  namespace           = "AWS/RDS"
  metric_name         = "WriteLatency"
  extended_statistic  = "p99"
  period              = 900
  evaluation_periods  = 1
  threshold           = 0.05
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = data.aws_db_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-rds-write-latency"
  }
}
