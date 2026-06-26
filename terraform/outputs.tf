# Airbyte Asset — Root Module Outputs

output "airbyte_url" {
  description = "HTTPS URL for the Airbyte web console."
  value       = module.airbyte.airbyte_url
}

output "alb_dns_name" {
  description = "ALB DNS name. Use this if no custom domain is configured."
  value       = module.airbyte.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port)."
  value       = module.airbyte.rds_endpoint
}

output "airbyte_admin_secret_arn" {
  description = "Secrets Manager ARN containing the Airbyte admin credentials. Populated after first boot."
  value       = module.airbyte.airbyte_admin_secret_arn
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN containing the RDS credentials."
  value       = module.airbyte.rds_secret_arn
}

output "s3_bucket_name" {
  description = "S3 bucket used by Airbyte for logs and artifacts."
  value       = module.airbyte.s3_bucket_name
}

output "instance_role_arn" {
  description = "IAM role ARN attached to the Airbyte EC2 instance. Attach additional policies for connector access."
  value       = module.airbyte.instance_role_arn
}

output "instance_sg_id" {
  description = "Security group ID of the Airbyte EC2 instance. Add ingress rules for bastion/VPN access."
  value       = module.airbyte.instance_sg_id
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt all Airbyte resources."
  value       = module.airbyte.kms_key_arn
}

output "asg_name" {
  description = "Auto Scaling Group name. Use for instance refresh operations."
  value       = module.airbyte.asg_name
}

output "log_group_name" {
  description = "CloudWatch log group for Airbyte logs."
  value       = module.airbyte.log_group_name
}
