# ---------------------------------------------------------------------------
# IAM User: dedicated least-privilege user for Airbyte Cloud
# ---------------------------------------------------------------------------
resource "aws_iam_user" "airbyte" {
  #checkov:skip=CKV_AWS_273: Airbyte Cloud requires static IAM credentials as SSO is not supported for external services
  name = "airbyte-cloud-data-ingestion"
  path = "/airbyte/"

  tags = merge(var.tags, { Name = "airbyte-cloud-data-ingestion" })
}

# ---------------------------------------------------------------------------
# IAM Access Key: stored in Secrets Manager
# ---------------------------------------------------------------------------
resource "aws_iam_access_key" "airbyte" {
  user = aws_iam_user.airbyte.name
}

# ---------------------------------------------------------------------------
# IAM Policy: least privilege scoped to bronze bucket and bronze Glue catalog
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "airbyte" {
  name        = "${local.name}-airbyte-least-privilege"
  description = "Minimal permissions for Airbyte Cloud to ingest data into S3 and register tables in Glue only in the Bronze layer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 - read-only access to the raw landing zone (source for Airbyte ingestion)
      {
        Sid    = "S3LandingZoneReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.buckets["raw"].arn,
          "${aws_s3_bucket.buckets["raw"].arn}/*"
        ]
      },
      # S3 - scoped to bronze bucket only
      {
        Sid    = "S3BronzeBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.buckets["bronze"].arn,
          "${aws_s3_bucket.buckets["bronze"].arn}/*"
        ]
      },
      # Glue - scoped to bronze database and its tables only
      {
        Sid    = "GlueBronzeCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:DeleteTable"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:database/escr20_bronze_dev",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:table/escr20_bronze_dev/*"
        ]
      },
      # KMS - use the Airbyte CMK for S3 encryption/decryption
      {
        Sid    = "KMSAirbyteKeyAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.airbyte[0].arn
      }
    ]
  })

  tags = merge(var.tags, { Name = "${local.name}-airbyte-least-privilege" })
}

# ---------------------------------------------------------------------------
# Policy Attachment: bind the policy to the Airbyte IAM user
# ---------------------------------------------------------------------------
resource "aws_iam_user_policy_attachment" "airbyte" {
  #checkov:skip=CKV_AWS_40: Airbyte Cloud IAM user, it can be swap to a group, but not mandatory, since only airbyte will use this user
  user       = aws_iam_user.airbyte.name
  policy_arn = aws_iam_policy.airbyte.arn
}