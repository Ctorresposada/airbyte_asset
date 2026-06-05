# Glue crawler alarms use custom metrics emitted by log metric filters in log_metric_filters.tf.

resource "aws_cloudwatch_metric_alarm" "glue_connect20_failure" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-glue-connect20-crawler-failure"
  alarm_description   = "Connect20 Glue crawler failed — new Connect20 data is in storage but not visible to Athena queries"
  namespace           = "Region20/Glue"
  metric_name         = "Connect20CrawlerFailure"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-glue-connect20-crawler-failure"
  }
}

resource "aws_cloudwatch_metric_alarm" "glue_connect20_duration" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-glue-connect20-crawler-duration"
  alarm_description   = "Connect20 Glue crawler took more than 60 minutes — investigate before the next scheduled run to prevent failure"
  namespace           = "Region20/Glue"
  metric_name         = "Connect20CrawlerDuration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3600
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-glue-connect20-crawler-duration"
  }
}

resource "aws_cloudwatch_metric_alarm" "glue_ascender_failure" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-glue-ascender-crawler-failure"
  alarm_description   = "Ascender Glue crawler failed — new Ascender data is in storage but not visible to Athena queries"
  namespace           = "Region20/Glue"
  metric_name         = "AscenderCrawlerFailure"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-glue-ascender-crawler-failure"
  }
}

resource "aws_cloudwatch_metric_alarm" "glue_ascender_duration" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-glue-ascender-crawler-duration"
  alarm_description   = "Ascender Glue crawler took more than 60 minutes — investigate before the next scheduled run to prevent failure"
  namespace           = "Region20/Glue"
  metric_name         = "AscenderCrawlerDuration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3600
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-glue-ascender-crawler-duration"
  }
}
