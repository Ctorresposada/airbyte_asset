# S3 Buckets for all layers (raw / bronze / silver)
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