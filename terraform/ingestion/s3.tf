# ---------------------------------------------------------------------------
# S3 Buckets for all layers (raw / bronze / silver)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "buckets" {
  for_each = var.buckets

  bucket = "${each.value.name}-${var.environment}"

  tags = merge(var.tags, {
    Name        = "${each.value.name}-${var.environment}"
    Environment = var.environment
    Layer       = each.value.layer
  })
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policies
resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  # Rule 1 — transition current objects to cheaper storage
  rule {
    id     = "${each.value.layer}-transition-current"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = each.value.transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = each.value.transition_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = each.value.expiration_days
    }
  }

  # Rule 2 — clean up incomplete multipart uploads
  rule {
    id     = "${each.value.layer}-abort-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Raw Landing Zone Bucket Prefixes (Ascender, TEA and Connect20) - for files ingestion process
resource "aws_s3_object" "ascender_prefix" {
  bucket  = aws_s3_bucket.buckets["raw"].id
  key     = "ascender/"
  content = ""

  tags = merge(var.tags, {
    Prefix = "ascender"
    Source = "Ascender"
    Layer  = "raw"
  })
}

resource "aws_s3_object" "ascender_invoice_prefix" {
  bucket  = aws_s3_bucket.buckets["raw"].id
  key     = "ascender/invoice/"
  content = ""

  tags = merge(var.tags, {
    Prefix = "ascender/invoice"
    Source = "Ascender"
    Layer  = "raw"
  })
}

resource "aws_s3_object" "tea_prefix" {
  bucket  = aws_s3_bucket.buckets["raw"].id
  key     = "tea/"
  content = ""

  tags = merge(var.tags, {
    Prefix = "tea"
    Source = "TEA"
    Layer  = "raw"
  })
}

resource "aws_s3_object" "connect20_prefix" {
  bucket  = aws_s3_bucket.buckets["raw"].id
  key     = "connect20/"
  content = ""

  tags = merge(var.tags, {
    Prefix = "connect20"
    Source = "CONNECT20"
    Layer  = "raw"
  })
}

# Cross-account CRR destination policy: allow the Ascender source account's
# replication role to write into raw/ascender/ only. Bucket-level list and
# versioning reads are required by S3 for destination validation.
data "aws_iam_policy_document" "raw_bucket_ascender_crr" {
  count = var.create ? 1 : 0

  statement {
    sid    = "AllowAscenderCRRReplicateToAscenderPrefix"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::472646798982:role/service-role/s3crr_role_for_esc20-ascender-data-warehouse-798982-us-east-1"]
    }

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]

    resources = ["${aws_s3_bucket.buckets["raw"].arn}/ascender/*"]
  }

  statement {
    sid    = "AllowAscenderCRRBucketValidation"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::472646798982:role/service-role/s3crr_role_for_esc20-ascender-data-warehouse-798982-us-east-1"]
    }

    actions = [
      "s3:List*",
      "s3:GetBucketVersioning",
    ]

    resources = [aws_s3_bucket.buckets["raw"].arn]
  }
}

# ---------------------------------------------------------------------------
# Connect20 cross-account delivery policy -- connect20/* prefix on raw bucket
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "raw_bucket_connect20_delivery" {
  count = var.create ? 1 : 0

  statement {
    sid    = "AllowConnect20DeliveryWrites"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::471808368523:role/developworks-egress-r20-delivery-role-dev",
        "arn:aws:iam::198058783748:role/developworks-egress-r20-delivery-role",
      ]
    }

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = ["${aws_s3_bucket.buckets["raw"].arn}/connect20/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  # AbortMultipartUpload does not support the s3:x-amz-acl condition key,
  # so it must live in a separate statement without a condition block.
  statement {
    sid    = "AllowConnect20DeliveryAbortMPU"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::471808368523:role/developworks-egress-r20-delivery-role-dev",
        "arn:aws:iam::198058783748:role/developworks-egress-r20-delivery-role",
      ]
    }

    actions = ["s3:AbortMultipartUpload"]

    resources = ["${aws_s3_bucket.buckets["raw"].arn}/connect20/*"]
  }
}

data "aws_iam_policy_document" "raw_bucket_policy" {
  count = var.create ? 1 : 0

  source_policy_documents = [
    data.aws_iam_policy_document.raw_bucket_ascender_crr[0].json,
    data.aws_iam_policy_document.raw_bucket_connect20_delivery[0].json,
  ]
}

resource "aws_s3_bucket_policy" "raw_ascender_crr" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.buckets["raw"].id
  policy = data.aws_iam_policy_document.raw_bucket_policy[0].json

  depends_on = [aws_s3_bucket_public_access_block.buckets]
}
