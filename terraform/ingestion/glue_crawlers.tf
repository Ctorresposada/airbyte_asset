# ---------------------------------------------------------------------------
# Glue Crawlers — one per entry in var.glue_crawlers
# Crawls source S3 prefixes on a schedule, auto-detects schema (CSV/Parquet/etc),
# and registers tables into the target Glue database.
# It will create one crawler per File Source (Ascender, Connect20, TEA)
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Custom CSV classifier — created only for crawlers with csv_classifier=true.
# Uses OpenCSVSerDe which correctly handles quoted fields containing commas,
# unlike the default LazySimpleSerDe used by the built-in CSV classifier (For Ascender)
# ---------------------------------------------------------------------------
resource "aws_glue_classifier" "csv_quoted" {
  for_each = var.create ? { for k, v in var.glue_crawlers : k => v if v.csv_classifier } : {}

  name = "${local.name}-${each.key}-csv-quoted"

  csv_classifier {
    delimiter              = each.value.csv_delimiter # comma, pipe, tab, etc
    quote_symbol           = "\""                     # trims whitespace from value
    contains_header        = "PRESENT"                # treats 1st row as headers
    disable_value_trimming = false                    # trims whitespace 
    allow_single_column    = false                    # rejects files with only one column (safety check)
    serde                  = "OpenCSVSerDe"           # correct SerDe for standard CSV files
  }
}

resource "aws_glue_crawler" "crawlers" {
  for_each = var.create ? var.glue_crawlers : {}

  name                   = "${local.name}-${each.key}-crawler"
  role                   = aws_iam_role.glue_crawlers[each.key].arn
  database_name          = aws_glue_catalog_database.databases[each.value.database_key].name
  schedule               = each.value.enabled ? each.value.schedule : null
  security_configuration = aws_glue_security_configuration.crawlers[each.key].name
  table_prefix           = each.value.table_prefix
  classifiers            = each.value.csv_classifier ? [aws_glue_classifier.csv_quoted[each.key].name] : null

  s3_target {
    path = "s3://${aws_s3_bucket.buckets[each.value.s3_bucket_key].id}/${each.value.s3_prefix}"
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
    Name        = "${local.name}-${each.key}"
    Environment = var.environment
    Source      = each.key
    Layer       = each.value.database_key
  })

  depends_on = [
    aws_iam_role_policy_attachment.glue_crawlers_service,
    aws_iam_role_policy.glue_crawlers_s3,
    aws_glue_security_configuration.crawlers,
  ]
}

# Shared assume-role policy for all crawler IAM roles
data "aws_iam_policy_document" "glue_crawler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_crawlers" {
  for_each = var.create ? var.glue_crawlers : {}

  name               = "${local.name}-glue-${each.key}-crawler"
  assume_role_policy = data.aws_iam_policy_document.glue_crawler_assume_role.json

  tags = merge(var.tags, {
    Name        = "${local.name}-glue-${each.key}-crawler"
    Environment = var.environment
  })
}

# AWSGlueServiceRole grants Glue service access to CloudWatch Logs, Glue catalog,
# and the baseline S3 permissions required by the crawler runtime.
#checkov:skip=CKV_AWS_274: AWSGlueServiceRole is the standard AWS-managed policy for Glue service roles
resource "aws_iam_role_policy_attachment" "glue_crawlers_service" {
  for_each = var.create ? var.glue_crawlers : {}

  role       = aws_iam_role.glue_crawlers[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Per-crawler S3 read policy scoped to the configured source prefix
data "aws_iam_policy_document" "glue_crawlers_s3" {
  for_each = var.create ? var.glue_crawlers : {}

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.buckets[each.value.s3_bucket_key].arn]
  }

  statement {
    sid       = "GetObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.buckets[each.value.s3_bucket_key].arn}/${each.value.s3_prefix}*"]
  }
}

resource "aws_iam_role_policy" "glue_crawlers_s3" {
  for_each = var.create ? var.glue_crawlers : {}

  name   = "${each.key}-s3-read"
  role   = aws_iam_role.glue_crawlers[each.key].id
  policy = data.aws_iam_policy_document.glue_crawlers_s3[each.key].json
}

# AWSGlueServiceRole does not include logs:AssociateKmsKey, which is required
# when a security configuration encrypts CloudWatch log groups with a KMS key.
data "aws_iam_policy_document" "glue_crawlers_logs" {
  statement {
    sid       = "AssociateKmsKeyToLogGroup"
    actions   = ["logs:AssociateKmsKey"]
    resources = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws-glue/crawlers-role/*"]
  }
}

resource "aws_iam_role_policy" "glue_crawlers_logs" {
  for_each = var.create ? var.glue_crawlers : {}

  name   = "${each.key}-cloudwatch-kms"
  role   = aws_iam_role.glue_crawlers[each.key].id
  policy = data.aws_iam_policy_document.glue_crawlers_logs.json
}

# ---------------------------------------------------------------------------
# KMS keys and security configurations — one per crawler (CKV_AWS_195)
# CloudWatch logs encrypted with a dedicated KMS key; S3 uses SSE-S3
# (consistent with the rest of the stack).
# ---------------------------------------------------------------------------

#checkov:skip=CKV_AWS_109: Resource:* in KMS key policies refers to the key itself — AWS-recommended root-access pattern for key management
#checkov:skip=CKV_AWS_111: kms:* on Resource:* is standard for KMS key policies and does not grant unconstrained write access to other resources
data "aws_iam_policy_document" "glue_crawlers_kms" {
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

resource "aws_kms_key" "glue_crawlers" {
  for_each = var.create ? var.glue_crawlers : {}

  description             = "KMS key for ${each.key} Glue crawler CloudWatch log encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.glue_crawlers_kms.json

  tags = merge(var.tags, {
    Name        = "${local.name}-glue-${each.key}-crawler"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "glue_crawlers" {
  for_each = var.create ? var.glue_crawlers : {}

  name          = "alias/${local.name}-glue-${each.key}-crawler"
  target_key_id = aws_kms_key.glue_crawlers[each.key].key_id
}

resource "aws_glue_security_configuration" "crawlers" {
  for_each = var.create ? var.glue_crawlers : {}

  name = "${local.name}-${each.key}-crawler"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = aws_kms_key.glue_crawlers[each.key].arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "DISABLED"
    }

    s3_encryption {
      s3_encryption_mode = "SSE-S3"
    }
  }
}

