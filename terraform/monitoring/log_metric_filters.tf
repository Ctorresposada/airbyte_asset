# ---------------------------------------------------------------------------
# Athena failed queries
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "athena_failed_queries" {
  count = var.create ? 1 : 0

  name           = "${local.name}-athena-failed-queries"
  log_group_name = var.athena_log_group_name
  pattern        = "\"QueryExecutionState\" \"FAILED\""

  metric_transformation {
    name          = "FailedQueries"
    namespace     = "Region20/Athena"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# ---------------------------------------------------------------------------
# Glue Connect20 crawler failure and duration
#
# The /aws-glue/crawlers log group receives one log stream per crawler run.
# Log lines include the crawler name, so the filter pattern scopes to the
# Connect20 crawler specifically.
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "glue_connect20_failure" {
  count = var.create ? 1 : 0

  name           = "${local.name}-glue-connect20-failure"
  log_group_name = "/aws-glue/crawlers"
  pattern        = "\"${local.name}-connect_20-crawler\" \"FAILED\""

  metric_transformation {
    name          = "Connect20CrawlerFailure"
    namespace     = "Region20/Glue"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

# Glue logs crawler duration in seconds as "Crawler run time: Xs" at completion.
# The filter extracts that value so the Duration alarm can threshold against it.
resource "aws_cloudwatch_log_metric_filter" "glue_connect20_duration" {
  count = var.create ? 1 : 0

  name           = "${local.name}-glue-connect20-duration"
  log_group_name = "/aws-glue/crawlers"
  pattern        = "\"${local.name}-connect_20-crawler\" \"Crawler run time\" [duration]"

  metric_transformation {
    name          = "Connect20CrawlerDuration"
    namespace     = "Region20/Glue"
    value         = "$duration"
    default_value = "0"
    unit          = "Seconds"
  }
}

# ---------------------------------------------------------------------------
# Glue Ascender crawler failure and duration
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "glue_ascender_failure" {
  count = var.create ? 1 : 0

  name           = "${local.name}-glue-ascender-failure"
  log_group_name = "/aws-glue/crawlers"
  pattern        = "\"${local.name}-ascender-crawler\" \"FAILED\""

  metric_transformation {
    name          = "AscenderCrawlerFailure"
    namespace     = "Region20/Glue"
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "glue_ascender_duration" {
  count = var.create ? 1 : 0

  name           = "${local.name}-glue-ascender-duration"
  log_group_name = "/aws-glue/crawlers"
  pattern        = "\"${local.name}-ascender-crawler\" \"Crawler run time\" [duration]"

  metric_transformation {
    name          = "AscenderCrawlerDuration"
    namespace     = "Region20/Glue"
    value         = "$duration"
    default_value = "0"
    unit          = "Seconds"
  }
}
