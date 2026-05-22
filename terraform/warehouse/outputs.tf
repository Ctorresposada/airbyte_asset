output "redshift_kms_key_arn" {
  description = "ARN of the KMS CMK used to encrypt Redshift data at rest, or null when the stack is disabled (create = false)."
  value       = try(module.redshift_kms[0].key_arn, null)
}

output "redshift_kms_key_id" {
  description = "Globally unique identifier of the Redshift KMS CMK, or null when the stack is disabled (create = false)."
  value       = try(module.redshift_kms[0].key_id, null)
}

output "redshift_workgroup_endpoint" {
  description = "Workgroup endpoint object (address + port) used by SQL clients to connect to Redshift, or null when the stack is disabled (create = false)."
  value       = try(aws_redshiftserverless_workgroup.this[0].endpoint, null)
}

output "redshift_workgroup_arn" {
  description = "ARN of the Redshift Serverless workgroup, or null when the stack is disabled."
  value       = try(aws_redshiftserverless_workgroup.this[0].arn, null)
}

output "redshift_namespace_arn" {
  description = "ARN of the Redshift Serverless namespace, or null when the stack is disabled."
  value       = try(aws_redshiftserverless_namespace.this[0].arn, null)
}

output "redshift_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Redshift admin password (Redshift-managed), or null when the stack is disabled."
  value       = try(aws_redshiftserverless_namespace.this[0].admin_password_secret_arn, null)
}

output "redshift_iam_role_arn" {
  description = "ARN of the IAM role attached to the Redshift Serverless namespace (S3 / Glue read for Spectrum), or null when the stack is disabled."
  value       = try(aws_iam_role.redshift_serverless[0].arn, null)
}

output "redshift_security_group_id" {
  description = "Security group ID protecting the Redshift workgroup, or null when the stack is disabled."
  value       = try(aws_security_group.redshift[0].id, null)
}

output "redshift_log_group_names" {
  description = "Names of the CloudWatch log groups receiving Redshift Serverless log exports, or null when the stack is disabled (create = false)."
  value       = try([for lg in aws_cloudwatch_log_group.redshift : lg.name], null)
}

output "redshift_log_group_arns" {
  description = "ARNs of the CloudWatch log groups receiving Redshift Serverless log exports, or null when the stack is disabled (create = false)."
  value       = try([for lg in aws_cloudwatch_log_group.redshift : lg.arn], null)
}

output "athena_workgroup_name" {
  description = "Athena primary workgroup name, or null when the stack is disabled."
  value       = try(aws_athena_workgroup.primary[0].name, null)
}

output "athena_results_bucket" {
  description = "S3 bucket ID for Athena query results, or null when the stack is disabled."
  value       = try(aws_s3_bucket.buckets["athena_results"].id, null)
}