output "aws_caller_identity" {
  description = "AWS caller identity information, or null when the stack is disabled (create = false)"
  value       = try(data.aws_caller_identity.this[0], null)
}

output "bucket_names" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.id
  }
  description = "All S3 bucket names"
}

output "bucket_arns" {
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.arn
  }
  description = "All S3 bucket ARNs"
}

output "glue_database_names" {
  value = {
    for k, v in aws_glue_catalog_database.databases : k => v.name
  }
  description = "Glue catalog database names"
}

output "airbyte_asg_name" {
  description = "Auto Scaling Group name for the Airbyte EC2 instance."
  value       = try(module.airbyte[0].asg_name, null)
}

output "airbyte_instance_sg_id" {
  description = "Instance security group ID for the Airbyte EC2 instance. Use this to allow ingress from other resources."
  value       = try(module.airbyte[0].instance_sg_id, null)
}

output "airbyte_rds_endpoint" {
  description = "RDS PostgreSQL endpoint for the Airbyte config database."
  value       = try(module.airbyte[0].rds_endpoint, null)
}

output "airbyte_s3_bucket_name" {
  description = "S3 bucket name used by Airbyte for logs and artifacts."
  value       = try(module.airbyte[0].s3_bucket_name, null)
}

output "airbyte_rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Airbyte RDS credentials."
  value       = try(module.airbyte[0].rds_secret_arn, null)
  sensitive   = true
}

output "user_data_script" {
  description = "Rendered user-data bootstrap script as it will be passed to the EC2 instance. Use 'terraform output -raw user_data_script' to inspect it before ap  plying."
  value       = module.airbyte[0].user_data_script
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Airbyte: expose secret ARN for reference (never expose the actual values)
# ---------------------------------------------------------------------------
output "airbyte_secret_arn" {
  description = "ARN of the Secrets Manager secret storing Airbyte credentials"
  value       = aws_secretsmanager_secret.airbyte_credentials.arn
}

output "airbyte_iam_user_arn" {
  description = "ARN of the Airbyte Cloud IAM user"
  value       = aws_iam_user.airbyte.arn
}