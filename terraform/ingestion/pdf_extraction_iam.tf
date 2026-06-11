# ---------------------------------------------------------------------------
# IAM: Lambda execution role for pdf_to_bronze
# ---------------------------------------------------------------------------
resource "aws_iam_role" "pdf_to_bronze_lambda" {
  count = var.create ? 1 : 0

  name = "${local.name}-pdf-to-bronze-lambda-role"
  path = "/pdf-extraction/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaAssume"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-pdf-to-bronze-lambda-role" })
}

# Grants CreateLogGroup, CreateLogStream, PutLogEvents — minimum for Lambda
# to write its stdout/stderr to CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "pdf_to_bronze_lambda_basic" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.pdf_to_bronze_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "pdf_to_bronze_lambda_permissions" {
  count = var.create ? 1 : 0

  name = "pdf-to-bronze-least-privilege"
  role = aws_iam_role.pdf_to_bronze_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3: read .pdf files from the raw bucket under the configured prefix only.
      # Scoped to suffix *.pdf so the role cannot read CSV/Parquet/other raw objects.
      {
        Sid    = "AllowS3ReadRawPDFs"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.buckets["raw"].arn}/${var.pdf_extraction_s3_prefix}*.pdf",
        ]
      },
      # S3: write Parquet files to bronze under pdf-extracted/ only.
      # ListBucket + GetBucketLocation are required by the pyarrow S3 filesystem
      # for bucket-existence checks during write.
      {
        Sid    = "AllowS3WriteBronzeParquet"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.buckets["bronze"].arn,
          "${aws_s3_bucket.buckets["bronze"].arn}/pdf-extracted/*",
        ]
      },
      # Glue: register and update tables in the bronze database.
      # GetDatabase is required for validation before CreateTable/UpdateTable.
      # Scoped to the bronze database and its tables — no access to raw or silver.
      {
        Sid    = "AllowGlueCatalogBronze"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:database/${aws_glue_catalog_database.databases["bronze"].name}",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:table/${aws_glue_catalog_database.databases["bronze"].name}/*",
        ]
      },
    ]
  })
}
