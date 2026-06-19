# ---------------------------------------------------------------------------
# IAM: Lambda execution role for the gdrive sync function
# ---------------------------------------------------------------------------
resource "aws_iam_role" "gdrive_sync_lambda" {
  count = var.create ? 1 : 0

  name = "${local.name}-gdrive-sync-lambda-role"
  path = "/gdrive-sync/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaAssume"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-gdrive-sync-lambda-role" })
}

# Basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "gdrive_sync_lambda_basic" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.gdrive_sync_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "gdrive_sync_lambda_permissions" {
  count = var.create ? 1 : 0

  name = "gdrive-sync-least-privilege"
  role = aws_iam_role.gdrive_sync_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3: write to tea/ prefix only
      {
        Sid    = "AllowS3WriteTEAPrefix"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.buckets["raw"].arn,
          "${aws_s3_bucket.buckets["raw"].arn}/tea/*",
        ]
      },
      # Secrets Manager: read the Google SA JSON
      {
        Sid    = "AllowReadGdriveSASecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.gdrive_sa[0].arn
      },
      # SSM: read and write the incremental sync cursor
      {
        Sid    = "AllowSSMCursor"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter",
        ]
        Resource = aws_ssm_parameter.gdrive_sync_cursor[0].arn
      },
      # EventBridge Scheduler: create/update the one-time schedule that
      # triggers the TEA Glue crawler after sync completes
      {
        Sid    = "AllowSchedulerManage"
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:GetSchedule",
        ]
        Resource = "arn:aws:scheduler:${var.aws_region}:${var.account_id}:schedule/default/${local.name}-tea-crawler-after-sync"
      },
      # PassRole: allow the Lambda to pass the scheduler execution role
      {
        Sid      = "AllowPassSchedulerRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.tea_crawler_scheduler[0].arn
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# IAM: EventBridge Scheduler role to start the TEA Glue crawler
# ---------------------------------------------------------------------------
resource "aws_iam_role" "tea_crawler_scheduler" {
  count = var.create ? 1 : 0

  name = "${local.name}-tea-crawler-scheduler-role"
  path = "/gdrive-sync/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSchedulerAssume"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-tea-crawler-scheduler-role" })
}

resource "aws_iam_role_policy" "tea_crawler_scheduler_glue" {
  count = var.create ? 1 : 0

  name = "start-tea-crawler"
  role = aws_iam_role.tea_crawler_scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowStartCrawler"
      Effect   = "Allow"
      Action   = "glue:StartCrawler"
      Resource = aws_glue_crawler.crawlers["tea"].arn
    }]
  })
}

# ---------------------------------------------------------------------------
# IAM: EventBridge Scheduler role to invoke the Lambda
# ---------------------------------------------------------------------------
resource "aws_iam_role" "gdrive_sync_scheduler" {
  count = var.create ? 1 : 0

  name = "${local.name}-gdrive-sync-scheduler-role"
  path = "/gdrive-sync/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSchedulerAssume"
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-gdrive-sync-scheduler-role" })
}

resource "aws_iam_role_policy" "gdrive_sync_scheduler_invoke" {
  count = var.create ? 1 : 0

  name = "invoke-gdrive-sync-lambda"
  role = aws_iam_role.gdrive_sync_scheduler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowInvokeLambda"
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = aws_lambda_function.gdrive_sync[0].arn
    }]
  })
}
