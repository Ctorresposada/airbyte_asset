# Module: airbyte-eks — Outputs

output "airbyte_url" {
  description = "HTTPS URL for the Airbyte web console. Null when domain_name is not set."
  value       = local.airbyte_url != "" ? local.airbyte_url : null
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint in host:port format."
  value       = "${aws_db_instance.this.address}:${aws_db_instance.this.port}"
}

output "airbyte_admin_secret_arn" {
  description = "Secrets Manager ARN for Airbyte web UI admin credentials. Populate manually after first Helm deploy by copying from the airbyte-auth-secrets Kubernetes secret."
  value       = aws_secretsmanager_secret.airbyte_admin.arn
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN containing the RDS credentials (username, password, host, port, dbname)."
  value       = aws_secretsmanager_secret.rds.arn
}

output "s3_bucket_name" {
  description = "S3 bucket used by Airbyte for logs and artifacts."
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used by Airbyte."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt all Airbyte resources."
  value       = aws_kms_key.this.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used to encrypt all Airbyte resources."
  value       = aws_kms_key.this.key_id
}

output "log_group_name" {
  description = "CloudWatch log group for Airbyte system logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "irsa_role_arn" {
  description = "IRSA role ARN for Airbyte pods. Attach additional policies here for connector access."
  value       = aws_iam_role.irsa_airbyte.arn
}

output "irsa_role_name" {
  description = "Name of the IRSA role for Airbyte pods."
  value       = aws_iam_role.irsa_airbyte.name
}

output "node_group_sg_id" {
  description = "Security group ID for the EKS node group."
  value       = aws_security_group.node_group.id
}

output "rds_sg_id" {
  description = "Security group ID for the RDS instance."
  value       = aws_security_group.rds.id
}

output "rds_instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "certificate_arn" {
  description = "ACM certificate ARN used by the ALB Ingress. Null when no domain is configured."
  value       = try(local.effective_certificate_arn, null)
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint. Used to configure the kubernetes/helm providers in the root module."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64-encoded). Used to configure the kubernetes/helm providers in the root module."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_group_name" {
  description = "EKS managed node group name."
  value       = aws_eks_node_group.this.node_group_name
}
