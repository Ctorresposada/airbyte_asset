# ---------------------------------------------------------------------------
# Connect20 Glue Crawler resources
# Crawls raw/connect20/ on a nightly schedule, detects Parquet schema, and
# registers tables into the bronze Glue database
# ---------------------------------------------------------------------------
resource "aws_glue_crawler" "connect20" {
  count = var.create ? 1 : 0

  name          = "${local.name}-connect20-crawler"
  role          = aws_iam_role.glue_connect20_crawler[0].arn
  database_name = aws_glue_catalog_database.databases["bronze"].name
  schedule      = var.glue_connect20_crawler_schedule

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
    Layer       = "bronze"
  })

  depends_on = [
    aws_iam_role_policy_attachment.glue_connect20_crawler_service,
    aws_iam_role_policy.glue_connect20_crawler_s3,
    aws_lakeformation_permissions.glue_connect20_crawler_bronze_db,
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
