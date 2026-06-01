output "ecr_repository_url" {
  description = "Full URL of the shared dbt Core ECR repository, or null when the stack is disabled (create = false). Consuming stacks pass this as the ecr_repository_url variable input."
  value       = try(aws_ecr_repository.dbt_core[0].repository_url, null)
}

output "ecr_repository_arn" {
  description = "ARN of the shared dbt Core ECR repository, or null when the stack is disabled. Consuming stacks use this to scope their ECR pull IAM statements."
  value       = try(aws_ecr_repository.dbt_core[0].arn, null)
}

output "ecr_repository_name" {
  description = "Short name of the shared dbt Core ECR repository, or null when the stack is disabled."
  value       = try(aws_ecr_repository.dbt_core[0].name, null)
}

output "ecr_kms_key_arn" {
  description = "ARN of the CMK encrypting the shared dbt Core ECR repository, or null when the stack is disabled."
  value       = try(module.service_account_kms[0].key_arn, null)
}
