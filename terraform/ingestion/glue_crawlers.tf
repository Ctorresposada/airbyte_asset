# ---------------------------------------------------------------------------
# Connect20 Glue Crawler resources
# Crawls raw/connect20/ on a nightly schedule, detects Parquet schema, and
# registers tables into the raw Glue database
# ---------------------------------------------------------------------------
resource "aws_glue_crawler" "connect20" {
  count = var.create ? 1 : 0

  name                   = "${local.name}-connect20-crawler"
  role                   = aws_iam_role.glue_connect20_crawler[0].arn
  database_name          = aws_glue_catalog_database.databases["raw"].name
  schedule               = var.glue_connect20_crawler_schedule
  security_configuration = aws_glue_security_configuration.connect20_crawler[0].name

  s3_target {
    path = "s3://${aws_s3_bucket.buckets["raw"].id}/connect20/"
  }

  # MergeNewColumns: adds columns that appear in new files without breaking
  # existing table definitions. CombineCompatibleSchemas: groups files under
  # the same prefix into a single table rather than one table per file.
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = merge(var.tags, {
    Name        = "${local.name}-connect20"
    Environment = var.environment
    Source      = "connect20"
    Layer       = "raw"
  })

  depends_on = [
    aws_iam_role_policy_attachment.glue_connect20_crawler_service,
    aws_iam_role_policy.glue_connect20_crawler_s3,
    aws_lakeformation_permissions.glue_connect20_crawler_raw_db,
    aws_glue_security_configuration.connect20_crawler,
  ]
}

# ---------------------------------------------------------------------------
# IAM role assumed by the Connect20 Glue crawler
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "glue_crawler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_connect20_crawler" {
  count = var.create ? 1 : 0

  name               = "${local.name}-glue-connect20-crawler"
  assume_role_policy = data.aws_iam_policy_document.glue_crawler_assume_role.json

  tags = merge(var.tags, {
    Name        = "${local.name}-glue-connect20-crawler"
    Environment = var.environment
  })
}

# AWSGlueServiceRole grants Glue service access to CloudWatch Logs, Glue catalog,
# and the baseline S3 permissions required by the crawler runtime.
#checkov:skip=CKV_AWS_274: AWSGlueServiceRole is the standard AWS-managed policy for Glue service roles
resource "aws_iam_role_policy_attachment" "glue_connect20_crawler_service" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.glue_connect20_crawler[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_connect20_crawler_s3" {
  statement {
    sid       = "ListRawBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.buckets["raw"].arn]
  }

  statement {
    sid       = "GetConnect20Objects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.buckets["raw"].arn}/connect20/*"]
  }
}

resource "aws_iam_role_policy" "glue_connect20_crawler_s3" {
  count = var.create ? 1 : 0

  name   = "connect20-s3-read"
  role   = aws_iam_role.glue_connect20_crawler[0].id
  policy = data.aws_iam_policy_document.glue_connect20_crawler_s3.json
}

# ---------------------------------------------------------------------------
# Glue security configuration — satisfies CKV_AWS_195
# CloudWatch logs encrypted with a dedicated KMS key; S3 uses SSE-S3
# (consistent with the rest of the stack).
# ---------------------------------------------------------------------------
#checkov:skip=CKV_AWS_109: Resource:* in a KMS key policy refers to the key itself — this is the AWS-recommended root-access pattern for key management
#checkov:skip=CKV_AWS_111: Same as above — kms:* on Resource:* is standard for KMS key policies and does not grant unconstrained write access to other resources
data "aws_iam_policy_document" "glue_connect20_crawler_kms" {
  statement {
    sid       = "EnableRootAccess"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  # CloudWatch Logs must be explicitly allowed to use the key for log group encryption.
  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "glue_connect20_crawler" {
  count = var.create ? 1 : 0

  description             = "KMS key for Connect20 Glue crawler CloudWatch log encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.glue_connect20_crawler_kms.json

  tags = merge(var.tags, {
    Name        = "${local.name}-glue-connect20-crawler"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "glue_connect20_crawler" {
  count = var.create ? 1 : 0

  name          = "alias/${local.name}-glue-connect20-crawler"
  target_key_id = aws_kms_key.glue_connect20_crawler[0].key_id
}

resource "aws_glue_security_configuration" "connect20_crawler" {
  count = var.create ? 1 : 0

  name = "${local.name}-connect20-crawler"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = aws_kms_key.glue_connect20_crawler[0].arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      s3_encryption_mode = "SSE-S3"
    }
  }
}
