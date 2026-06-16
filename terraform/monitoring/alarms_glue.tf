# ---------------------------------------------------------------------------
# Glue crawler failure — EventBridge rule on "Glue Crawler State Change"
#
# Glue does not write crawler logs to a predictable CloudWatch log group when a
# security configuration encrypts CloudWatch logs (the logs land under
# /aws-glue/crawlers-role/<role>-<config> rather than /aws-glue/crawlers), and a
# crawler that has never run creates no log group at all. A log metric filter is
# therefore the wrong tool. EventBridge "Glue Crawler State Change" events fire
# from aws.glue with detail.state Started | Succeeded | Failed and carry
# detail.crawlerName, requiring no log group and working even before the first
# run. This mirrors the dbt task-failure pattern in alarms_dbt_ecs.tf.
#
# Crawler names are deterministic: "${local.name}-<key>-crawler" (see the
# ingestion stack, terraform/ingestion/glue_crawlers.tf).
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "glue_crawler_failure" {
  count = var.create ? 1 : 0

  name        = "${local.name}-glue-crawler-failure"
  description = "Fires when the Connect20 or Ascender Glue crawler reports a Failed state — new data is in storage but not yet visible to Athena queries"

  event_pattern = jsonencode({
    source      = ["aws.glue"]
    detail-type = ["Glue Crawler State Change"]
    detail = {
      state = ["Failed"]
      crawlerName = [
        "${local.name}-connect_20-crawler",
        "${local.name}-ascender-crawler",
        "${local.name}-tea-crawler"
      ]
    }
  })

  tags = {
    Name = "${local.name}-glue-crawler-failure"
  }
}

resource "aws_cloudwatch_event_target" "glue_crawler_failure_sns" {
  count = var.create ? 1 : 0

  rule = aws_cloudwatch_event_rule.glue_crawler_failure[0].name
  arn  = aws_sns_topic.critical[0].arn
}

# ---------------------------------------------------------------------------
# Crawler duration is intentionally not alarmed.
#
# AWS Glue exposes no CloudWatch metric for crawler run duration, and the
# "Glue Crawler State Change" event carries no elapsed-time field that an
# EventBridge rule could threshold. The only way to observe crawler duration
# natively would be a custom Lambda computing the delta between the Started and
# Succeeded/Failed event timestamps and emitting a custom metric — overhead that
# is not justified here. A broken log-metric-filter-based duration alarm (the
# previous implementation) is worse than no alarm, so the duration alarm is
# dropped. Crawler *failures* are still caught by the EventBridge rule above.
# ---------------------------------------------------------------------------
