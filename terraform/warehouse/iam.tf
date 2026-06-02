data "aws_iam_policy_document" "redshift_serverless" {
  count = var.create && length(var.data_lake_bucket_arns) > 0 ? 1 : 0

  statement {
    sid    = "S3ObjectRead"
    effect = "Allow"

    actions = ["s3:GetObject"]

    resources = [for arn in var.data_lake_bucket_arns : "${arn}/*"]
  }

  statement {
    sid    = "S3BucketRead"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = var.data_lake_bucket_arns
  }

  statement {
    sid    = "GlueCatalogRead"
    effect = "Allow"

    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "LakeFormationGetDataAccess"
    effect = "Allow"

    actions   = ["lakeformation:GetDataAccess"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "redshift_serverless" {
  count = var.create ? 1 : 0

  name = "${local.name}-redshift-serverless"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["redshift.amazonaws.com", "redshift-serverless.amazonaws.com"] }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "redshift_serverless" {
  count = var.create && length(var.data_lake_bucket_arns) > 0 ? 1 : 0

  name   = "${local.name}-redshift-serverless-s3-glue"
  role   = aws_iam_role.redshift_serverless[0].id
  policy = data.aws_iam_policy_document.redshift_serverless[0].json
}
