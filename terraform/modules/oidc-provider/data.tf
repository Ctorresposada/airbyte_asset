data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = var.create_oidc_provider ? [aws_iam_openid_connect_provider.github[0].arn] : [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    dynamic "condition" {
      for_each = length(var.github_repositories) > 0 ? [1] : []
      content {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values = [
          for repo in var.github_repositories :
          "repo:${repo}:*"
        ]
      }
    }

    dynamic "condition" {
      for_each = var.github_organization != null ? [1] : []
      content {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values   = ["repo:${var.github_organization}/*"]
      }
    }
  }
}
