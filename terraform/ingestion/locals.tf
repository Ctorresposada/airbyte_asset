locals {
  name = "${var.company_name}-${var.environment}"

  airbyte_secret_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "secretsmanager:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAirbyteUserReadOnly"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.airbyte.arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
    ]
  })
}
