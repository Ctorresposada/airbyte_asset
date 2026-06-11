# ---------------------------------------------------------------------------
# Lambda Layer: Python dependencies for pdf_to_bronze.py
#
# !! PLACEHOLDER ZIP — rebuild before the first `terraform apply` !!
#
# The layer zip must be built for the linux/x86_64 Lambda runtime.
# Run once from the repo root (requires Docker or a Linux host with pip):
#
#   cd terraform/ingestion/lambda
#
#   # Option A — cross-compile on macOS/Windows (recommended):
#   pip install pdfplumber pandas pyarrow \
#       --target python/lib/python3.12/site-packages \
#       --platform manylinux2014_x86_64 \
#       --python-version 3.12 \
#       --only-binary=:all: -q
#
#   # Option B — build inside a matching Lambda container:
#   docker run --rm \
#       -v "$PWD":/build -w /build \
#       public.ecr.aws/lambda/python:3.12 \
#       pip install pdfplumber pandas pyarrow \
#           -t python/lib/python3.12/site-packages -q
#
#   zip -r pdf_extraction_layer.zip python/
#   rm -rf python/
#
# The zip is checked in to terraform/ingestion/lambda/pdf_extraction_layer.zip.
# Rebuild and re-commit whenever a dependency version changes.
# ---------------------------------------------------------------------------
resource "aws_lambda_layer_version" "pdf_extraction_deps" {
  count = var.create ? 1 : 0

  filename            = "${path.module}/lambda/pdf_extraction_layer.zip"
  layer_name          = "${local.name}-pdf-extraction-deps"
  description         = "pdfplumber + pandas + pyarrow for pdf_to_bronze Lambda"
  compatible_runtimes = ["python3.12"]
  source_code_hash    = filebase64sha256("${path.module}/lambda/pdf_extraction_layer.zip")
}

# ---------------------------------------------------------------------------
# Lambda Function: pdf_to_bronze.py
#
# Triggered by S3 ObjectCreated for .pdf files in the raw landing bucket.
# Extracts all tables (multi-page aware), writes Snappy Parquet to the bronze
# bucket under pdf-extracted/<table_name>/, and registers/updates the Glue
# catalog table so Athena can query it immediately.
#
# One Lambda handles all PDF schemas — each filename becomes its own Glue
# table (district_campus_numbers → escr20_bronze_dev.district_campus_numbers).
# dbt Silver models read from those bronze tables and cast columns as needed.
#
# Rebuild the code zip when pdf_to_bronze.py changes:
#   cd terraform/ingestion/lambda && zip pdf_to_bronze_code.zip pdf_to_bronze.py
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "pdf_to_bronze" {
  #checkov:skip=CKV_AWS_117: VPC not required — Lambda accesses only S3 and Glue via AWS service endpoints
  #checkov:skip=CKV_AWS_50: X-Ray tracing optional for an event-driven ingestion job; can be enabled before GA
  #checkov:skip=CKV_AWS_116: DLQ not required — S3 event source retries twice; failures are visible in CloudWatch Logs
  #checkov:skip=CKV_AWS_173: Env vars contain only non-secret resource identifiers (bucket name, Glue DB name)
  #checkov:skip=CKV_AWS_272: Code-signing not required in dev; enable before GA
  #checkov:skip=CKV_AWS_115: Concurrency limit not set — TEA PDFs arrive infrequently; no concurrent execution risk
  count = var.create ? 1 : 0

  function_name    = "${local.name}-pdf-to-bronze"
  description      = "Extracts tables from TEA PDF files and writes Snappy Parquet to the bronze bucket"
  filename         = "${path.module}/lambda/pdf_to_bronze_code.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/pdf_to_bronze_code.zip")
  handler          = "pdf_to_bronze.handler"
  runtime          = "python3.12"
  timeout          = var.pdf_extraction_timeout
  memory_size      = var.pdf_extraction_memory
  role             = aws_iam_role.pdf_to_bronze_lambda[0].arn
  # Two layers: pdfplumber (custom) + pandas/pyarrow (AWS-managed public layer).
  # Splitting avoids the 250 MB unzipped Lambda limit — pyarrow alone is ~130 MB.
  layers = [
    aws_lambda_layer_version.pdf_extraction_deps[0].arn,
    var.pdf_extraction_pandas_layer_arn,
  ]

  environment {
    variables = {
      BRONZE_BUCKET = aws_s3_bucket.buckets["bronze"].id
      GLUE_DATABASE = aws_glue_catalog_database.databases["bronze"].name
    }
  }

  tags = merge(var.tags, { Name = "${local.name}-pdf-to-bronze" })
}

resource "aws_cloudwatch_log_group" "pdf_to_bronze" {
  #checkov:skip=CKV_AWS_158: KMS encryption not required for Lambda logs — consistent with CKV_AWS_145 project decision; SSE-S3 sufficient
  count = var.create ? 1 : 0

  name              = "/aws/lambda/${local.name}-pdf-to-bronze"
  retention_in_days = var.pdf_extraction_log_retention_days

  tags = merge(var.tags, { Name = "${local.name}-pdf-to-bronze-logs" })
}

# ---------------------------------------------------------------------------
# S3 → Lambda wiring
#
# aws_lambda_permission must exist before aws_s3_bucket_notification or AWS
# will reject the notification config with "Unable to validate the following
# destination configurations". The depends_on in the notification resource
# makes this ordering explicit for Terraform.
# ---------------------------------------------------------------------------
resource "aws_lambda_permission" "pdf_to_bronze_s3" {
  count = var.create ? 1 : 0

  statement_id  = "AllowS3InvokePDFToBronze"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_to_bronze[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.buckets["raw"].arn
  # source_account prevents the confused-deputy attack where any bucket in any
  # account could invoke this function if they guess the ARN.
  source_account = var.account_id
}

# S3 event notification: invoke the Lambda on every .pdf ObjectCreated event
# under the configured prefix (default: tea/).
#
# NOTE: AWS allows only one aws_s3_bucket_notification per bucket. If the raw
# bucket needs additional event notifications in future, add extra
# lambda_function / queue / topic blocks to this single resource rather than
# creating a separate aws_s3_bucket_notification — the latter would silently
# overwrite this one.
resource "aws_s3_bucket_notification" "raw_pdf_trigger" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.buckets["raw"].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf_to_bronze[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.pdf_extraction_s3_prefix
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.pdf_to_bronze_s3]
}
