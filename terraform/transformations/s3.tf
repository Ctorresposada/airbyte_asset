# dbt artifacts bucket — stores compiled dbt artifacts (manifest.json, run_results.json,
# catalog.json), target/ output, and run logs. SSE-KMS with the stack CMK, versioned,
# all public access blocked.
resource "aws_s3_bucket" "dbt_artifacts" {
  #checkov:skip=CKV_AWS_18: Access logging not required — audit trail handled via CloudTrail data events at the org level.
  #checkov:skip=CKV_AWS_144: Cross-region replication not required — dbt artifacts are reproducible build outputs, no DR requirement.
  #checkov:skip=CKV2_AWS_62: Event notifications not required — dbt run orchestration does not consume S3 events.
  #checkov:skip=CKV_AWS_300: Abort-incomplete-multipart lifecycle not required for this low-churn artifacts bucket.
  #checkov:skip=CKV2_AWS_61: Ensure that an S3 bucket has a lifecycle configuration.
  #checkov:skip=CKV2_AWS_6: Ensure that S3 bucket has a Public Access block.
  #checkov:skip=CKV_AWS_21: Ensure all data stored in the S3 bucket have versioning enabled.

  count = var.create ? 1 : 0

  bucket = "${var.company_name}-dbt-artifacts-${var.environment}"

  tags = merge(var.tags, {
    Name        = "${var.company_name}-dbt-artifacts-${var.environment}"
    Environment = var.environment
    Layer       = "dbt-artifacts"
  })
}

resource "aws_s3_bucket_public_access_block" "dbt_artifacts" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.dbt_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbt_artifacts" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.dbt_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.transformations_kms[0].key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "dbt_artifacts" {
  count = var.create ? 1 : 0

  bucket = aws_s3_bucket.dbt_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}
