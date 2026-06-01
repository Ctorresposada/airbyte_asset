# Shared dbt Core ECR repository. Lives in the service account so a single image
# build is pulled cross-account by the dev and prod workload accounts. Immutable
# tags, scan-on-push for vulnerability detection, KMS encryption with this
# stack's own CMK.
resource "aws_ecr_repository" "dbt_core" {
  count = var.create ? 1 : 0

  name                 = "${local.name}-dbt-core"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = module.service_account_kms[0].key_arn
  }

  tags = merge(var.tags, {
    Name = "${local.name}-dbt-core"
  })
}

# Keep the last N tagged images; expire untagged images after 1 day.
resource "aws_ecr_lifecycle_policy" "dbt_core" {
  count = var.create ? 1 : 0

  repository = aws_ecr_repository.dbt_core[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent ${var.ecr_image_retention_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", var.environment]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_image_retention_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

# Cross-account pull policy. Grants the dev and prod workload account roots the
# minimal actions required to pull an image. Granting to the account root lets
# each account further delegate pull access to its own principals (e.g. the ECS
# task execution role) via that account's IAM policies, without this policy
# enumerating every consuming role.
data "aws_iam_policy_document" "dbt_core_cross_account_pull" {
  count = var.create ? 1 : 0

  statement {
    sid    = "AllowCrossAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for id in var.consumer_account_ids : "arn:aws:iam::${id}:root"]
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "dbt_core" {
  count = var.create ? 1 : 0

  repository = aws_ecr_repository.dbt_core[0].name
  policy     = data.aws_iam_policy_document.dbt_core_cross_account_pull[0].json
}
