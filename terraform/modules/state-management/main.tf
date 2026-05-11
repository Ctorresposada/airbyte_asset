module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.10.0"

  bucket = var.s3_bucket_name

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms_key.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

module "kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.5.0"

  description = "KMS key for Terraform state encryption"
  key_usage   = "ENCRYPT_DECRYPT"

  aliases = [var.kms_key_alias]


  enable_default_policy = var.kms_enable_default_policy
  key_administrators    = var.kms_key_administrators
  key_users             = var.kms_key_users

  key_statements = [
    {
      sid    = "Allow S3 and DynamoDB to use the KMS key"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
      principals = [
        {
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        }
      ]
      conditions = [
        {
          test     = "StringEquals"
          variable = "kms:ViaService"
          values   = ["s3.${data.aws_region.current.region}.amazonaws.com"]
        },
        {
          test     = "StringEquals"
          variable = "kms:CallerAccount"
          values   = [data.aws_caller_identity.current.account_id]
        }
      ]
    }
  ]
}

resource "aws_iam_policy" "state_management" {
  count       = var.create_state_management_iam_policy ? 1 : 0
  name        = "${var.state_management_iam_policy_name}-${module.s3_bucket.s3_bucket_id}"
  description = var.state_management_iam_policy_description

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:List*",
          "s3:Get*",
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketAcl",
        ]
        Resource = module.s3_bucket.s3_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Get*",
          "kms:List*",
          "kms:Describe*",
          "kms:CreateKey",
          "kms:EnableKey",
          "kms:DisableKey",
          "kms:ScheduleKeyDeletion",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
          "kms:PutKeyPolicy",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
        Resource = module.kms_key.key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:List*"
        ]
        Resource = "*"
      },

    ]
  })
}
