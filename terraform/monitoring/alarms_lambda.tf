resource "aws_cloudwatch_metric_alarm" "lambda_sync_errors" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-gdrive-sync-errors"
  alarm_description   = "3 or more gdrive-sync Lambda errors in 10 minutes — today's TEA data may not have been copied to the data lake"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-gdrive-sync"
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-lambda-gdrive-sync-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_sync_throttling" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-gdrive-sync-throttling"
  alarm_description   = "5 or more gdrive-sync Lambda throttles in 10 minutes — ingestion is delayed; consider requesting a concurrency increase"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-gdrive-sync"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-gdrive-sync-throttling"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_sync_duration" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-gdrive-sync-duration"
  alarm_description   = "gdrive-sync Lambda max duration exceeded 13.5 minutes (90% of the 15-minute hard limit) — sync may be cut off as data volume grows"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 810000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-gdrive-sync"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-gdrive-sync-duration"
  }
}

# Error rate alarm uses metric math: Errors / Invocations.
# m1 and m2 are anonymous metric queries; the expression result is the alarm signal.
resource "aws_cloudwatch_metric_alarm" "lambda_sync_error_rate" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-gdrive-sync-error-rate"
  alarm_description   = "gdrive-sync Lambda error rate exceeded 5% — sync is unreliable even if total error count is low"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0.05
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors / MAX([errors, invocations])"
    label       = "Error Rate"
    return_data = true
  }

  metric_query {
    id = "errors"

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      stat        = "Sum"
      period      = 600

      dimensions = {
        FunctionName = "${local.name}-gdrive-sync"
      }
    }
  }

  metric_query {
    id = "invocations"

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      stat        = "Sum"
      period      = 600

      dimensions = {
        FunctionName = "${local.name}-gdrive-sync"
      }
    }
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-lambda-gdrive-sync-error-rate"
  }
}
