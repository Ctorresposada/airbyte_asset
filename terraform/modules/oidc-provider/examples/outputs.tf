output "specific_repos_role_arn" {
  description = "ARN of the role for specific repositories"
  value       = module.github_oidc_specific_repos.iam_role_arn
}

output "specific_repos_config" {
  description = "GitHub Actions configuration for specific repos"
  value       = module.github_oidc_specific_repos.github_actions_config
}

output "org_wide_role_arn" {
  description = "ARN of the organization-wide role"
  value       = module.github_oidc_org_wide.iam_role_arn
}

output "ecr_push_role_arn" {
  description = "ARN of the ECR push role"
  value       = module.github_oidc_ecr_push.iam_role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.github_oidc_specific_repos.oidc_provider_arn
}