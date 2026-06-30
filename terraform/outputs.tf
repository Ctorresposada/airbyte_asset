# Airbyte Asset — Root Module Outputs
# Outputs pull from whichever module is active (ec2 or eks).
# Outputs that are not applicable to the active deployment_type return null.

output "airbyte_url" {
  description = "HTTPS URL for the Airbyte web console."
  value       = try(module.airbyte_ec2[0].airbyte_url, module.airbyte_eks[0].airbyte_url, null)
}

output "alb_dns_name" {
  description = "ALB DNS name. Use this if no custom domain is configured. Null for EKS (ALB is controller-managed)."
  value       = try(module.airbyte_ec2[0].alb_dns_name, null)
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port)."
  value       = try(module.airbyte_ec2[0].rds_endpoint, module.airbyte_eks[0].rds_endpoint, null)
}

output "airbyte_admin_secret_arn" {
  description = "Secrets Manager ARN containing the Airbyte admin credentials. Populated after first boot."
  value       = try(module.airbyte_ec2[0].airbyte_admin_secret_arn, module.airbyte_eks[0].airbyte_admin_secret_arn, null)
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN containing the RDS credentials."
  value       = try(module.airbyte_ec2[0].rds_secret_arn, module.airbyte_eks[0].rds_secret_arn, null)
}

output "s3_bucket_name" {
  description = "S3 bucket used by Airbyte for logs and artifacts."
  value       = try(module.airbyte_ec2[0].s3_bucket_name, module.airbyte_eks[0].s3_bucket_name, null)
}

output "instance_role_arn" {
  description = "IAM role ARN for Airbyte. EC2: instance profile role. EKS: IRSA role. Attach additional policies here for connector access."
  value       = try(module.airbyte_ec2[0].instance_role_arn, module.airbyte_eks[0].irsa_role_arn, null)
}

output "instance_sg_id" {
  description = "Security group ID for the Airbyte compute layer. EC2: instance SG. EKS: node group SG. Null if not applicable."
  value       = try(module.airbyte_ec2[0].instance_sg_id, module.airbyte_eks[0].node_group_sg_id, null)
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt all Airbyte resources."
  value       = try(module.airbyte_ec2[0].kms_key_arn, module.airbyte_eks[0].kms_key_arn, null)
}

output "asg_name" {
  description = "Auto Scaling Group name. Use for instance refresh operations. Null for EKS deployments."
  value       = try(module.airbyte_ec2[0].asg_name, null)
}

output "log_group_name" {
  description = "CloudWatch log group for Airbyte logs."
  value       = try(module.airbyte_ec2[0].log_group_name, module.airbyte_eks[0].log_group_name, null)
}

output "eks_cluster_name" {
  description = "EKS cluster name. Null for EC2 deployments."
  value       = try(module.airbyte_eks[0].cluster_name, null)
}
