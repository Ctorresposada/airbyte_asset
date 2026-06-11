# ---------------------------------------------------------------------------
# IAM: TEA Schema Enforcer Lambda execution role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "tea_schema_enforcer_assume_role" {
  count = var.create ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "tea_schema_enforcer_lambda" {
  count = var.create ? 1 : 0

  name               = "${local.name}-tea-schema-enforcer-lambda"
  assume_role_policy = data.aws_iam_policy_document.tea_schema_enforcer_assume_role[0].json

  tags = merge(var.tags, { Name = "${local.name}-tea-schema-enforcer-lambda" })
}

# Basic execution role: CloudWatch Logs write access
resource "aws_iam_role_policy_attachment" "tea_schema_enforcer_basic" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.tea_schema_enforcer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Glue permissions: read all tea_* tables, update their schema
resource "aws_iam_role_policy" "tea_schema_enforcer_glue" {
  count = var.create ? 1 : 0

  name = "glue-schema-enforce"
  role = aws_iam_role.tea_schema_enforcer_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GlueReadTables"
        Effect = "Allow"
        Action = [
          "glue:GetTables",
          "glue:GetTable",
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:database/${aws_glue_catalog_database.databases["bronze"].name}",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:table/${aws_glue_catalog_database.databases["bronze"].name}/tea_*",
        ]
      },
      {
        Sid    = "GlueUpdateTables"
        Effect = "Allow"
        Action = ["glue:UpdateTable"]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${var.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:database/${aws_glue_catalog_database.databases["bronze"].name}",
          "arn:aws:glue:${var.aws_region}:${var.account_id}:table/${aws_glue_catalog_database.databases["bronze"].name}/tea_*",
        ]
      },
    ]
  })
}
