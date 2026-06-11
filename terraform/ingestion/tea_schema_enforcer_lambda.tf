# ---------------------------------------------------------------------------
# TEA Schema Enforcer Lambda
#
# Triggered automatically by EventBridge when the TEA Glue crawler
# completes successfully. Sets every column in every tea_* bronze table
# to type "string", preventing Athena NumberFormatException errors caused
# by empty strings in columns that Glue inferred as numeric.
#
# Proper type casting is handled downstream in dbt silver models.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "tea_schema_enforcer" {
  #checkov:skip=CKV_AWS_158: KMS encryption not required for Lambda logs — consistent with CKV_AWS_145 project decision; SSE-S3 sufficient
  count = var.create ? 1 : 0

  name              = "/aws/lambda/${local.name}-tea-schema-enforcer"
  retention_in_days = var.tea_schema_enforcer_log_retention_days

  tags = merge(var.tags, { Name = "${local.name}-tea-schema-enforcer-logs" })
}

resource "aws_lambda_function" "tea_schema_enforcer" {
  #checkov:skip=CKV_AWS_117: VPC not required — Lambda accesses only Glue via AWS service endpoints
  #checkov:skip=CKV_AWS_50:  X-Ray tracing optional for an event-driven post-crawl job
  #checkov:skip=CKV_AWS_116: DLQ not required — EventBridge retries twice on failure; errors visible in CloudWatch Logs
  #checkov:skip=CKV_AWS_173: Env vars contain only non-secret resource identifiers (Glue DB name, table prefix)
  #checkov:skip=CKV_AWS_272: Code-signing not required in dev; enable before GA
  #checkov:skip=CKV_AWS_115: Concurrency limit not set — post-crawl job runs at most once per crawler execution
  count = var.create ? 1 : 0

  function_name    = "${local.name}-tea-schema-enforcer"
  description      = "Sets all tea_* bronze Glue table columns to string after each TEA crawler run"
  filename         = "${path.module}/lambda/tea_schema_enforcer_code.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/tea_schema_enforcer_code.zip")
  handler          = "tea_schema_enforcer.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 128
  role             = aws_iam_role.tea_schema_enforcer_lambda[0].arn

  environment {
    variables = {
      GLUE_DATABASE = aws_glue_catalog_database.databases["bronze"].name
      TABLE_PREFIX  = "tea_"
    }
  }

  depends_on = [aws_cloudwatch_log_group.tea_schema_enforcer]

  tags = merge(var.tags, { Name = "${local.name}-tea-schema-enforcer" })
}

# ---------------------------------------------------------------------------
# EventBridge rule: fire when the TEA crawler state changes to Succeeded
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "tea_crawler_succeeded" {
  count = var.create ? 1 : 0

  name        = "${local.name}-tea-crawler-succeeded"
  description = "Fires when the TEA Glue crawler completes successfully"

  event_pattern = jsonencode({
    source        = ["aws.glue"]
    "detail-type" = ["Glue Crawler State Change"]
    detail = {
      crawlerName = [aws_glue_crawler.crawlers["tea"].name]
      state       = ["Succeeded"]
    }
  })

  tags = merge(var.tags, { Name = "${local.name}-tea-crawler-succeeded" })
}

resource "aws_cloudwatch_event_target" "tea_schema_enforcer" {
  count = var.create ? 1 : 0

  rule      = aws_cloudwatch_event_rule.tea_crawler_succeeded[0].name
  target_id = "TeaSchemaEnforcer"
  arn       = aws_lambda_function.tea_schema_enforcer[0].arn
}

resource "aws_lambda_permission" "tea_schema_enforcer_eventbridge" {
  count = var.create ? 1 : 0

  statement_id  = "AllowEventBridgeInvokeSchemaEnforcer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tea_schema_enforcer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tea_crawler_succeeded[0].arn
}
