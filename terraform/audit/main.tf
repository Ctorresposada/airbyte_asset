# Stack: audit
# Provisions the centralized VPC Flow Logs S3 bucket and KMS CMK in the audit account.

# ---------------------------------------------------------------------------
# Flow Logs — KMS CMK
# ---------------------------------------------------------------------------

module "flow_log_kms" {
  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description             = "CMK for centralized VPC Flow Logs in the audit account — ${local.name}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  aliases = ["alias/${local.name}-vpc-flow-logs"]

  key_statements = [
    {
      sid    = "AllowVPCFlowLogsCrossAccountKMSUse"
      effect = "Allow"
      actions = [
        "kms:GenerateDataKey*",
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:DescribeKey",
      ]
      resources = ["*"]
      principals = [
        {
          type        = "Service"
          identifiers = ["delivery.logs.amazonaws.com"]
        }
      ]
      conditions = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = var.source_account_ids
        },
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = [for acct in var.source_account_ids : "arn:aws:logs:*:${acct}:*"]
        },
      ]
    },
  ]
}

# ---------------------------------------------------------------------------
# Flow Logs — bucket policy
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "flow_log_bucket" {
  count = var.create ? 1 : 0

  # Allows the VPC Flow Logs service to write log files into the bucket.
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.flow_log_bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.source_account_ids
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [for acct in var.source_account_ids : "arn:aws:logs:*:${acct}:*"]
    }
  }

  # Allows the VPC Flow Logs service to read bucket ACL before delivering logs.
  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${var.flow_log_bucket_name}"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.source_account_ids
    }
  }
}

# ---------------------------------------------------------------------------
# Flow Logs — S3 bucket
# ---------------------------------------------------------------------------

module "flow_log_bucket" {
  #checkov:skip=CKV_AWS_18: Access logging on the flow-log bucket would create a recursive log delivery loop
  #checkov:skip=CKV_AWS_144: Cross-region replication is explicitly out of scope for this audit stack
  #checkov:skip=CKV_AWS_21: Versioning adds cost without value for append-only AWS-delivered flow logs

  count = var.create ? 1 : 0

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket        = var.flow_log_bucket_name
  force_destroy = var.flow_log_bucket_force_destroy

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.flow_log_kms[0].key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "expire-flow-logs"
      enabled = true

      expiration = {
        days = var.flow_log_retention_days
      }
    }
  ]

  attach_policy = true
  policy        = data.aws_iam_policy_document.flow_log_bucket[0].json
}
