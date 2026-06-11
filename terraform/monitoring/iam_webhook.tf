# ---------------------------------------------------------------------------
# IAM for the Airbyte webhook Lambda
# ---------------------------------------------------------------------------

resource "aws_iam_role" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  name        = "${local.name}-airbyte-webhook-lambda"
  description = "Execution role for the ${local.name} Airbyte webhook Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name}-airbyte-webhook-lambda-role"
  }
}

# Inline policy — least privilege for SNS publish + KMS + CloudWatch Logs.
resource "aws_iam_role_policy" "airbyte_webhook" {
  count = local.enable_webhook ? 1 : 0

  name = "${local.name}-airbyte-webhook-lambda-policy"
  role = aws_iam_role.airbyte_webhook[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = [
          aws_sns_topic.warning[0].arn,
          aws_sns_topic.critical[0].arn,
        ]
      },
      {
        Sid    = "AllowKMSForSNS"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = aws_kms_key.sns[0].arn
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.airbyte_webhook[0].arn}:*"
      },
    ]
  })
}

# Attach the AWS-managed basic execution policy. This grants CreateLogGroup in
# addition to the log stream/event permissions above, which is required on first
# invocation before the log group is confirmed to exist in the execution context.
resource "aws_iam_role_policy_attachment" "airbyte_webhook_basic_execution" {
  count = local.enable_webhook ? 1 : 0

  role       = aws_iam_role.airbyte_webhook[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
