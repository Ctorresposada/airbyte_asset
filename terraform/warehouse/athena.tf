# Athena S3 results bucket
resource "aws_s3_bucket" "buckets" {
  #checkov:skip=CKV_AWS_18: Access logging for transient Athena query results not required
  #checkov:skip=CKV_AWS_144: Cross-region replication not required for transient Athena query results
  #checkov:skip=CKV_AWS_145: Athena workgroup enforces SSE_S3; a separate KMS CMK for this transient bucket adds cost without meaningful security benefit
  #checkov:skip=CKV2_AWS_62: Event notifications not required for Athena results bucket
  for_each = var.create ? local.athena_buckets : {}

  bucket = each.value

  tags = merge(var.tags, {
    Name        = each.value
    Environment = var.environment
  })
}

resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = var.create ? local.athena_buckets : {}

  bucket                  = aws_s3_bucket.buckets[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = var.create ? local.athena_buckets : {}

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "buckets" {
  for_each = var.create ? local.athena_buckets : {}

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  #checkov:skip=CKV_AWS_300: Ensure S3 lifecycle configuration sets period for aborting failed uploads cost without meaningful security benefit

  for_each = var.create ? local.athena_buckets : {}

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    id     = "athena-results-lifecycle"
    status = "Enabled"

    transition {
      days          = var.athena_results.transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.athena_results.transition_glacier
      storage_class = "GLACIER"
    }

    expiration {
      days = var.athena_results.expiration_days
    }
  }
}

# Athena Workgroup — primary
resource "aws_athena_workgroup" "primary" {
  count = var.create ? 1 : 0

  name        = "primary"
  description = "Primary Athena workgroup for querying results - Bronze and Silver layers"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.buckets["athena_results"].id}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = merge(var.tags, {
    Name        = "primary-athena-workgroup-${var.environment}"
    Environment = var.environment
  })
}
