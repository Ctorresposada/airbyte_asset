# S3 storage metrics are reported by AWS once per day, so period = 86400 and
# treat_missing_data = notBreaching prevent false positives between metric deliveries.

resource "aws_cloudwatch_metric_alarm" "s3_raw_bucket_empty" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-s3-raw-bucket-empty"
  alarm_description   = "Raw S3 bucket has zero objects — all upstream data feeds (Ascender, Connect20, Google Drive sync) may have stopped"
  namespace           = "AWS/S3"
  metric_name         = "NumberOfObjects"
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = "escr20-landing-zone-raw-${var.environment}"
    StorageType = "AllStorageTypes"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-s3-raw-bucket-empty"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_bronze_bucket_empty" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-s3-bronze-bucket-empty"
  alarm_description   = "Bronze S3 bucket has zero objects — the pipeline step that cleans and stages raw data may have stopped"
  namespace           = "AWS/S3"
  metric_name         = "NumberOfObjects"
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = "escr20-bronze-${var.environment}"
    StorageType = "AllStorageTypes"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-s3-bronze-bucket-empty"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_silver_bucket_empty" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-s3-silver-bucket-empty"
  alarm_description   = "Silver S3 bucket has zero objects — the structured analytical layer is unavailable"
  namespace           = "AWS/S3"
  metric_name         = "NumberOfObjects"
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = "escr20-silver-${var.environment}"
    StorageType = "AllStorageTypes"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-s3-silver-bucket-empty"
  }
}
