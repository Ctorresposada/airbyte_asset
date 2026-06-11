resource "aws_cloudwatch_metric_alarm" "airbyte_cpu" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-ec2-cpu"
  alarm_description   = "Airbyte EC2 CPU utilization exceeded 80% for 15 minutes — sync jobs may be competing for CPU; consider scaling up"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 900
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = data.aws_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-ec2-cpu"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_status_check" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-ec2-status-check"
  alarm_description   = "Airbyte EC2 instance failed AWS health check — server is unresponsive; all syncs are halted; restart via AWS console"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 120
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = data.aws_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-airbyte-ec2-status-check"
  }
}

# disk_used_percent and mem_used_percent are emitted by the CloudWatch Agent
# running on the Airbyte instance, not the native EC2 namespace.
resource "aws_cloudwatch_metric_alarm" "airbyte_disk" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-ec2-disk"
  alarm_description   = "Airbyte EC2 disk usage exceeded 85% — Docker images and logs are filling the disk; clean up or expand the volume before containers crash"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = data.aws_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-airbyte-ec2-disk"
  }
}

resource "aws_cloudwatch_metric_alarm" "airbyte_memory" {
  count = var.create && var.enable_airbyte_monitoring ? 1 : 0

  alarm_name          = "${local.name}-airbyte-ec2-memory"
  alarm_description   = "Airbyte EC2 memory usage exceeded 85% for 15 minutes — sync jobs may fail or become sluggish; consider scaling to a larger instance type"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  statistic           = "Maximum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = data.aws_instance.airbyte[0].id
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-airbyte-ec2-memory"
  }
}
