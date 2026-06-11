# Module: airbyte-compute
# Outputs expose the identifiers consumers need to wire this module into
# the broader stack (DNS records, monitoring, cross-stack references, etc.).

output "alb_dns_name" {
  description = "ALB DNS name. Null when create_alb = false."
  value       = try(aws_lb.this[0].dns_name, null)
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB. Used by Route53 alias records. Null when create_alb = false."
  value       = try(aws_lb.this[0].zone_id, null)
}

output "alb_sg_id" {
  description = "ID of the security group attached to the internal ALB. Null when create_alb = false."
  value       = try(aws_security_group.alb[0].id, null)
}

output "asg_name" {
  description = "Name of the Auto Scaling Group managing the Airbyte EC2 instance."
  value       = try(aws_autoscaling_group.this[0].name, null)
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to the Airbyte EC2 instance profile. Grant this role additional permissions at the stack level if needed."
  value       = try(aws_iam_role.this[0].arn, null)
}

output "instance_role_name" {
  description = "Name of the IAM role attached to the Airbyte EC2 instance profile. Use this to attach additional policies at the stack level."
  value       = try(aws_iam_role.this[0].name, null)
}

output "instance_sg_id" {
  description = "ID of the security group attached to the Airbyte EC2 instance."
  value       = try(aws_security_group.instance[0].id, null)
}

output "ssm_parameter_name" {
  description = "Name of the SSM SecureString parameter that holds the rendered Airbyte Helm values YAML. The EC2 instance reads this at boot via user-data."
  value       = try(aws_ssm_parameter.airbyte_values[0].name, null)
}

output "log_group_name" {
  description = "Name of the CloudWatch log group for Airbyte system and pod logs."
  value       = try(aws_cloudwatch_log_group.this[0].name, null)
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint in host:port format. Null when create = false."
  value       = try("${aws_db_instance.this[0].address}:${aws_db_instance.this[0].port}", null)
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials (username, password, host, port, dbname). Null when create = false."
  value       = try(aws_secretsmanager_secret.rds[0].arn, null)
}

output "rds_sg_id" {
  description = "Security group ID of the RDS instance. Null when create = false."
  value       = try(aws_security_group.rds[0].id, null)
}

output "airbyte_admin_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Airbyte web UI admin credentials (username, password). Populated at instance boot by user-data. Null when create = false."
  value       = try(aws_secretsmanager_secret.airbyte_admin[0].arn, null)
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used by Airbyte for logs and artifacts. Null when create = false."
  value       = try(aws_s3_bucket.this[0].id, null)
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used by Airbyte for logs and artifacts. Null when create = false."
  value       = try(aws_s3_bucket.this[0].arn, null)
}

output "rds_instance_id" {
  description = "RDS instance identifier for the Airbyte config database. Use for snapshot, restore, or parameter group operations."
  value       = try(aws_db_instance.this[0].identifier, null)
}

output "user_data_script" {
  description = "Rendered user-data bootstrap script as it will be passed to the EC2 instance. Use 'terraform output -raw user_data_script' to inspect it before applying."
  value       = local.user_data_content
}
