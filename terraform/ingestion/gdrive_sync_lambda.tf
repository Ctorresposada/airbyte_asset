# ---------------------------------------------------------------------------
# Lambda Layer: Python dependencies for gdrive_to_s3.py
#
# Build locally before apply:
#   cd terraform/ingestion/lambda
#   pip install google-api-python-client google-auth \
#       --target python/lib/python3.12/site-packages -q
#   zip -r gdrive_sync_layer.zip python/
#
# The zip is checked in to terraform/ingestion/lambda/gdrive_sync_layer.zip
# and referenced here. Rebuild whenever dependencies change.
# ---------------------------------------------------------------------------
resource "aws_lambda_layer_version" "gdrive_deps" {
  count = var.create ? 1 : 0

  filename            = "${path.module}/lambda/gdrive_sync_layer.zip"
  layer_name          = "${local.name}-gdrive-sync-deps"
  description         = "google-api-python-client + google-auth for gdrive_to_s3 Lambda"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = filebase64sha256("${path.module}/lambda/gdrive_sync_layer.zip")
}

# ---------------------------------------------------------------------------
# Lambda Function: gdrive_to_s3.py
#
# The function code is pre-zipped and committed at lambda/gdrive_sync_code.zip.
# Rebuild when gdrive_to_s3.py changes:
#   cd terraform/ingestion/lambda && zip gdrive_sync_code.zip gdrive_to_s3.py
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "gdrive_sync" {
  #checkov:skip=CKV_AWS_117: VPC not required — Lambda calls Google APIs and S3 via public endpoints
  #checkov:skip=CKV_AWS_50: X-Ray tracing optional for a scheduled batch job
  #checkov:skip=CKV_AWS_116: DLQ not required — failures are visible in CloudWatch Logs; EventBridge retries handle transient errors
  #checkov:skip=CKV_AWS_173: Env vars contain only non-secret resource names (bucket, SSM path, secret name); actual secret is fetched at runtime via SDK
  #checkov:skip=CKV_AWS_272: Code-signing not required in dev; can be enabled before GA
  #checkov:skip=CKV_AWS_115: Concurrency limit not set — this is a single scheduled job with no concurrent execution risk
  count = var.create ? 1 : 0

  function_name    = "${local.name}-gdrive-sync"
  description      = "Syncs TEA Google Drive folder to S3 raw landing zone (incremental)"
  filename         = "${path.module}/lambda/gdrive_sync_code.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/gdrive_sync_code.zip")
  handler          = "gdrive_to_s3.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.gdrive_sync_timeout
  memory_size      = var.gdrive_sync_memory
  role             = aws_iam_role.gdrive_sync_lambda[0].arn
  layers           = [aws_lambda_layer_version.gdrive_deps[0].arn]

  environment {
    variables = {
      SECRET_NAME     = aws_secretsmanager_secret.gdrive_sa[0].name
      S3_BUCKET       = aws_s3_bucket.buckets["raw"].id
      S3_PREFIX       = "tea/"
      SSM_CURSOR_PATH = aws_ssm_parameter.gdrive_sync_cursor[0].name
      DRIVE_FOLDER_ID = var.gdrive_tea_folder_id
    }
  }

  tags = merge(var.tags, { Name = "${local.name}-gdrive-sync" })
}

resource "aws_cloudwatch_log_group" "gdrive_sync" {
  #checkov:skip=CKV_AWS_158: KMS encryption not required for Lambda logs — consistent with CKV_AWS_145 project decision; SSE-S3 sufficient
  count = var.create ? 1 : 0

  name              = "/aws/lambda/${local.name}-gdrive-sync"
  retention_in_days = var.gdrive_sync_log_retention_days

  tags = merge(var.tags, { Name = "${local.name}-gdrive-sync-logs" })
}

# ---------------------------------------------------------------------------
# EventBridge Scheduler: trigger the Lambda on a cron schedule
# ---------------------------------------------------------------------------
resource "aws_scheduler_schedule" "gdrive_sync" {
  #checkov:skip=CKV_AWS_297: CMK for EventBridge Scheduler not required in dev; consistent with project KMS decision
  count = var.create && var.gdrive_sync_enabled ? 1 : 0

  name                         = "${local.name}-gdrive-sync"
  description                  = "Daily Google Drive TEA folder → S3 raw landing zone sync"
  schedule_expression          = var.gdrive_sync_schedule
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.gdrive_sync[0].arn
    role_arn = aws_iam_role.gdrive_sync_scheduler[0].arn

    # Pass full_refresh = false for normal scheduled runs.
    # To trigger a full refresh manually: invoke the Lambda with
    #   aws lambda invoke --function-name <name> \
    #     --payload '{"full_refresh": true}' /dev/stdout
    input = jsonencode({ full_refresh = false })

    retry_policy {
      maximum_retry_attempts       = 2
      maximum_event_age_in_seconds = 3600
    }
  }
}
