output "ecr_repository_url" {
  description = "URL of the shared dbt Core ECR repository this stack pulls from. Owned by the service-account stack and passed in via var.ecr_repository_url."
  value       = var.ecr_repository_url
}

output "ecs_cluster_arn" {
  description = "ARN of the transformations ECS cluster, or null when the stack is disabled."
  value       = try(aws_ecs_cluster.this[0].arn, null)
}

output "ecs_task_definition_arn" {
  description = "ARN of the dbt Core ECS task definition (latest revision), or null when the stack is disabled."
  value       = try(aws_ecs_task_definition.dbt_core[0].arn, null)
}

output "dbt_task_role_arn" {
  description = "ARN of the dbt Core ECS task role (runtime identity), or null when the stack is disabled."
  value       = try(aws_iam_role.dbt_task[0].arn, null)
}

output "dbt_task_execution_role_arn" {
  description = "ARN of the dbt Core ECS task execution role (image pull + log stream), or null when the stack is disabled."
  value       = try(aws_iam_role.dbt_execution[0].arn, null)
}

output "dbt_ecs_security_group_id" {
  description = "Security group ID attached to the dbt Core Fargate tasks, or null when the stack is disabled."
  value       = try(aws_security_group.dbt_ecs[0].id, null)
}

output "dbt_artifacts_bucket_id" {
  description = "ID (name) of the dbt artifacts S3 bucket, or null when the stack is disabled."
  value       = try(aws_s3_bucket.dbt_artifacts[0].id, null)
}

output "dbt_log_group_name" {
  description = "Name of the CloudWatch log group receiving dbt Core ECS task logs, or null when the stack is disabled."
  value       = try(aws_cloudwatch_log_group.dbt_core[0].name, null)
}

output "dbt_private_subnet_ids" {
  description = "Private-app subnet IDs the dbt Core Fargate task should run in (awsvpc network configuration for run-task), or null when the stack is disabled."
  value       = try(data.aws_subnets.private[0].ids, null)
}

output "transformations_kms_key_arn" {
  description = "ARN of the transformations stack KMS CMK, or null when the stack is disabled."
  value       = try(module.transformations_kms[0].key_arn, null)
}

output "dbt_scheduler_arn" {
  description = "ARN of the EventBridge Scheduler rule that triggers the daily dbt pipeline, or null when scheduling is disabled."
  value       = try(aws_scheduler_schedule.dbt_pipeline[0].arn, null)
}
