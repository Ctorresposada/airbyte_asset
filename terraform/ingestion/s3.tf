# Creates Raw Bucket for 
resource "aws_s3_bucket" "raw" {
  bucket = var.raw_bucket_name

  tags = merge(var.tags, {
    Name        = var.raw_bucket_name
    Environment = var.environment
    Layer       = "raw"
  })
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 encryption (server-side encryption)
resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3 current
      # will need to swap to aws:kms later
    }
    bucket_key_enabled = true
  }
}

# Versioning raw bucket
resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  # Rule 1 — transition current objects to cheaper storage
  rule {
    id     = "raw-transition-current"
    status = "Enabled"

    filter {
      prefix = "" # applies to all objects
    }

    # move to Infrequent Access after 90 days
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    # move to Glacier after 365 days
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # delete after 7 years (adjust per retention requirements)
    expiration {
      days = 2555
    }
  }

  # Rule 2 — clean up incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
