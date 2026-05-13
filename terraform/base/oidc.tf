module "github_oidc" {
  #checkov:skip=CKV_AWS_274: Disallow IAM roles, users, and groups from using the AWS AdministratorAccess policy

  source = "../modules/oidc-provider"

  role_name        = "${var.company_name}-terraform-role"
  role_description = "IAM role for GitHub Actions deployments"

  # Restrict to specific repositories
  github_repositories = [
    "caylent/region-20-infrastructure",
    "esc-region-20/r20-data-lake-infrastructure"
  ]

  # Attach AWS managed policies
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  max_session_duration = 3600 # 1 hour
}
