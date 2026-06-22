# ---------------------------------------------------------------------------
# gdrive-sync Lambda alarms (retrigger plan after stale artifact)
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# pdf_to_bronze Lambda alarms
# Triggered by S3 ObjectCreated for .pdf files in the raw bucket (tea/ prefix).
# One Lambda invocation per PDF — any error means a file was not ingested.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_pdf_to_bronze_errors" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-pdf-to-bronze-errors"
  alarm_description   = "Any pdf_to_bronze Lambda error — a TEA PDF was not extracted to bronze; check CloudWatch Logs for details"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-pdf-to-bronze"
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-lambda-pdf-to-bronze-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_pdf_to_bronze_throttling" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-pdf-to-bronze-throttling"
  alarm_description   = "pdf_to_bronze Lambda throttled 3 or more times in 10 minutes — PDF ingestion is delayed"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-pdf-to-bronze"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-pdf-to-bronze-throttling"
  }
}

# ---------------------------------------------------------------------------
# tea-bronze-router Lambda alarms
# Triggered by S3 ObjectCreated for CSV/PDF files in the raw bucket (tea/ prefix).
# One Lambda invocation per file — any error means a file was not routed to bronze.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_tea_router_errors" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-tea-bronze-router-errors"
  alarm_description   = "Any tea-bronze-router Lambda error — a TEA file was not routed to bronze; check CloudWatch Logs for details"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-tea-bronze-router"
  }

  alarm_actions = [aws_sns_topic.critical[0].arn]
  ok_actions    = [aws_sns_topic.critical[0].arn]

  tags = {
    Name = "${local.name}-lambda-tea-bronze-router-errors"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_tea_router_throttling" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-tea-bronze-router-throttling"
  alarm_description   = "tea-bronze-router Lambda throttled 3 or more times in 10 minutes — TEA file ingestion is delayed"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 600
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-tea-bronze-router"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-tea-bronze-router-throttling"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_tea_router_duration" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-tea-bronze-router-duration"
  alarm_description   = "tea-bronze-router Lambda max duration exceeded 13.5 minutes (90% of the 15-minute hard limit) — Parquet conversion may be struggling with a large CSV"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 810000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-tea-bronze-router"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-tea-bronze-router-duration"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_pdf_to_bronze_duration" {
  count = var.create ? 1 : 0

  alarm_name          = "${local.name}-lambda-pdf-to-bronze-duration"
  alarm_description   = "pdf_to_bronze Lambda max duration exceeded 4.5 minutes (90% of the 5-minute hard limit) — pdfplumber may be struggling with a large PDF"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 270000
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "${local.name}-pdf-to-bronze"
  }

  alarm_actions = [aws_sns_topic.warning[0].arn]
  ok_actions    = [aws_sns_topic.warning[0].arn]

  tags = {
    Name = "${local.name}-lambda-pdf-to-bronze-duration"
  }
}