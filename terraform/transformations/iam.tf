# ---------------------------------------------------------------------------
# ECS task execution role — used by the ECS agent to pull the image and write
# the initial log stream. No Secrets Manager access needed — dbt uses the task
# role for AWS service access, so there is no secret to inject at task launch.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "dbt_execution" {
  count = var.create ? 1 : 0

  name = "${local.name}-dbt-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-execution"
  })
}

resource "aws_iam_role_policy_attachment" "dbt_execution_managed" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.dbt_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "dbt_execution" {
  count = var.create ? 1 : 0

  # Scoped ECR pull for this repo only (AmazonECSTaskExecutionRolePolicy grants
  # the account-wide ecr:GetAuthorizationToken; the layer/manifest reads below
  # are pinned to the dbt-core repository ARN).
  statement {
    sid    = "EcrPull"
    effect = "Allow"

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]

    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "dbt_execution" {
  count = var.create ? 1 : 0

  name   = "${local.name}-dbt-execution-inline"
  role   = aws_iam_role.dbt_execution[0].id
  policy = data.aws_iam_policy_document.dbt_execution[0].json
}

# ---------------------------------------------------------------------------
# ECS task role — the identity the dbt container itself assumes at runtime.
# Grants S3 access to the artifacts, Athena results, and silver buckets,
# CloudWatch Logs writes, and KMS use for SSE-KMS on the artifacts bucket. dbt
# uses the Athena adapter to transform S3 data and never connects to Redshift
# directly, so no Redshift IAM is required.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "dbt_task" {
  count = var.create ? 1 : 0

  name = "${local.name}-dbt-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-task"
  })
}

data "aws_iam_policy_document" "dbt_task" {
  count = var.create ? 1 : 0

  statement {
    sid    = "S3ArtifactObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.dbt_artifacts[0].arn}/*"]
  }

  statement {
    sid    = "S3ArtifactBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [aws_s3_bucket.dbt_artifacts[0].arn]
  }

  # Athena results bucket — dbt writes query results here via the Athena adapter.
  statement {
    sid    = "AthenaBucketObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${data.aws_s3_bucket.athena_results[0].arn}/*"]
  }

  statement {
    sid    = "AthenaBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [data.aws_s3_bucket.athena_results[0].arn]
  }

  # Silver bucket — read-only source data dbt transforms via the Athena adapter.
  statement {
    sid    = "SilverBucketObjects"
    effect = "Allow"

    actions = ["s3:GetObject"]

    resources = ["${data.aws_s3_bucket.silver[0].arn}/*"]
  }

  statement {
    sid    = "SilverBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [data.aws_s3_bucket.silver[0].arn]
  }

  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.dbt_core[0].arn}:*",
      "${aws_cloudwatch_log_group.cluster[0].arn}:*",
    ]
  }

  # SSE-KMS on the artifacts bucket: encrypt on PutObject, decrypt on GetObject.
  statement {
    sid    = "ArtifactsKmsUse"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [module.transformations_kms[0].key_arn]
  }
}

resource "aws_iam_role_policy" "dbt_task" {
  count = var.create ? 1 : 0

  name   = "${local.name}-dbt-task-inline"
  role   = aws_iam_role.dbt_task[0].id
  policy = data.aws_iam_policy_document.dbt_task[0].json
}
