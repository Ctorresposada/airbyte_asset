resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = var.thumbprint_list

  tags = merge(
    var.tags,
    {
      Name = "github-oidc-provider"
    }
  )
}

resource "aws_iam_role" "github_actions" {
  name                 = var.role_name
  description          = var.role_description
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = var.max_session_duration

  tags = merge(
    var.tags,
    {
      Name = var.role_name
    }
  )
}

resource "aws_iam_role_policy_attachment" "github_actions_custom" {
  count = var.attach_custom_policy && var.custom_policy_arn != null ? 1 : 0

  role       = aws_iam_role.github_actions.name
  policy_arn = var.custom_policy_arn
}

resource "aws_iam_role_policy_attachment" "github_actions_managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "github_actions_inline" {
  count = var.attach_inline_policy && var.inline_policy_json != null ? 1 : 0

  name   = "${var.role_name}-inline-policy"
  role   = aws_iam_role.github_actions.id
  policy = var.inline_policy_json
}
