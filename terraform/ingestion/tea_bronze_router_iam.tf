# ---------------------------------------------------------------------------
# IAM: Lambda execution role for the TEA bronze router function
# ---------------------------------------------------------------------------
resource "aws_iam_role" "tea_bronze_router_lambda" {
  count = var.create ? 1 : 0

  name = "${local.name}-tea-bronze-router-role"
  path = "/tea-bronze-router/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaAssume"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-tea-bronze-router-role" })
}

# Basic Lambda execution (CloudWatch Logs write access)
resource "aws_iam_role_policy_attachment" "tea_bronze_router_lambda_basic" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.tea_bronze_router_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "tea_bronze_router_lambda_permissions" {
  count = var.create ? 1 : 0

  name = "tea-bronze-router-least-privilege"
  role = aws_iam_role.tea_bronze_router_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3: read from raw/tea/ — GetObject for file content (CSV header), ListBucket for backfill pagination
      {
        Sid    = "AllowS3ReadRawTEA"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.buckets["raw"].arn,
          "${aws_s3_bucket.buckets["raw"].arn}/tea/*",
        ]
      },
      # S3: write to bronze/tea/ — PutObject for server-side copies, GetObject for
      # head_object existence checks in backfill mode, ListBucket for backfill pagination
      {
        Sid    = "AllowS3WriteBronzeTEA"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.buckets["bronze"].arn,
          "${aws_s3_bucket.buckets["bronze"].arn}/tea/*",
        ]
      },
    ]
  })
}
