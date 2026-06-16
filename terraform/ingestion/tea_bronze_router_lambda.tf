# ---------------------------------------------------------------------------
# CloudWatch Log Group: tea_bronze_router Lambda
#
# Created before the function so logs are retained even if the function is
# recreated. Retention mirrors the gdrive_sync pattern in this stack.
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "tea_bronze_router" {
  #checkov:skip=CKV_AWS_158: Log group encryption with KMS not required — consistent with other Lambda log groups in this stack
  count = var.create ? 1 : 0

  name              = "/aws/lambda/${local.name}-tea-bronze-router"
  retention_in_days = var.tea_bronze_router_log_retention_days

  tags = merge(var.tags, { Name = "${local.name}-tea-bronze-router" })
}

# ---------------------------------------------------------------------------
# Lambda Function: tea_bronze_router.py
#
# Routes files dropped under raw/tea/ to the correct bronze/tea/<subfolder>/
# based on file extension and (for CSVs) column count.
#
# The function code is pre-zipped and committed at lambda/tea_bronze_router_code.zip.
# Rebuild when tea_bronze_router.py changes:
#   cd terraform/ingestion/lambda && zip tea_bronze_router_code.zip tea_bronze_router.py
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "tea_bronze_router" {
  #checkov:skip=CKV_AWS_117: VPC not required — Lambda only calls S3 via AWS service endpoints
  #checkov:skip=CKV_AWS_50: X-Ray tracing optional for an event-driven routing function
  #checkov:skip=CKV_AWS_116: DLQ not required — failures surface in CloudWatch Logs; S3 event retries handle transient errors
  #checkov:skip=CKV_AWS_173: Env vars contain only non-secret resource names (bucket names); no secrets stored here
  #checkov:skip=CKV_AWS_272: Code-signing not required in dev; can be enabled before GA
  #checkov:skip=CKV_AWS_115: Concurrency limit not set — S3 event-driven function; volume is bounded by TEA delivery cadence
  count = var.create ? 1 : 0

  function_name    = "${local.name}-tea-bronze-router"
  description      = "Routes files from raw/tea/ to bronze/tea/<subfolder>/; converts narrow CSVs to Snappy Parquet"
  filename         = "${path.module}/lambda/tea_bronze_router_code.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/tea_bronze_router_code.zip")
  handler          = "tea_bronze_router.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.tea_bronze_router_timeout
  memory_size      = var.tea_bronze_router_memory
  role             = aws_iam_role.tea_bronze_router_lambda[0].arn
  layers           = [var.pdf_extraction_pandas_layer_arn]

  environment {
    variables = {
      RAW_BUCKET    = aws_s3_bucket.buckets["raw"].id
      BRONZE_BUCKET = aws_s3_bucket.buckets["bronze"].id
    }
  }

  tags = merge(var.tags, { Name = "${local.name}-tea-bronze-router" })

  depends_on = [aws_cloudwatch_log_group.tea_bronze_router]
}

# ---------------------------------------------------------------------------
# Lambda Permission: allow the raw S3 bucket to invoke this function
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "tea_bronze_router_s3" {
  count = var.create ? 1 : 0

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tea_bronze_router[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.buckets["raw"].arn
}

# NOTE: S3 allows only one aws_s3_bucket_notification per bucket.
# The tea_bronze_router trigger is merged into aws_s3_bucket_notification.raw_tea_notifications
# in pdf_extraction_lambda.tf, which owns all raw-bucket event wiring for the tea/ prefix.
