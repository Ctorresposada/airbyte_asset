output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the GitHub OIDC provider"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].url : "https://token.actions.githubusercontent.com"
}

output "iam_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.name
}

output "iam_role_unique_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.github_actions.unique_id
}

output "github_actions_config" {
  description = "GitHub Actions workflow configuration snippet"
  value       = <<-EOT
    # Add this to your GitHub Actions workflow file (.github/workflows/*.yml)

    permissions:
      id-token: write   # Required for OIDC
      contents: read

    jobs:
      your-job:
        runs-on: ubuntu-latest
        steps:
          - name: Configure AWS credentials
            uses: aws-actions/configure-aws-credentials@v4
            with:
              role-to-assume: ${aws_iam_role.github_actions.arn}
              aws-region: $${AWS_REGION}  # Set your AWS region
              role-session-name: GitHubActions-$${GITHUB_RUN_ID}
  EOT
}
