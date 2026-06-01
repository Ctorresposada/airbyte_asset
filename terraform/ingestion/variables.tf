variable "create" {
  description = "Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code."
  type        = bool
  default     = true
}

variable "environment" {
  type        = string
  description = "Target deployment environment"
}

variable "aws_region" {
  description = "Target deployment region"
  type        = string
}

variable "team" {
  description = "Team that manages this project"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "buckets" {
  description = "Map of S3 buckets to manage"
  type = map(object({
    name               = string
    layer              = string
    transition_ia      = number
    transition_glacier = number
    expiration_days    = number
  }))
}

variable "glue_databases" {
  description = "Map of Glue catalog databases to manage"
  type = map(object({
    name        = string
    description = string
  }))
}

variable "tags" {
  description = "Common tags to apply to all resources required"
  type        = map(string)
  default     = {}
}

variable "company_name" {
  description = "Company name prefix used in resource names and to look up shared networking resources by tag."
  type        = string
}

variable "airbyte_instance_type" {
  description = "EC2 instance type for the Airbyte ASG. Use m6a.xlarge for dev (minimum viable) and m6a.2xlarge for production."
  type        = string
  default     = "m6a.2xlarge"
}

variable "airbyte_rds_instance_class" {
  description = "RDS instance class for the Airbyte PostgreSQL config database. db.t3.micro for dev; db.t3.small or larger for production."
  type        = string
  default     = "db.t3.small"
}

variable "airbyte_log_retention_days" {
  description = "CloudWatch log retention in days for the Airbyte log group. Use 30 for dev to control cost; 365 for production."
  type        = number
  default     = 365
}

variable "airbyte_rds_multi_az" {
  description = "Enable RDS Multi-AZ standby for the Airbyte config database. Disable in dev for cost; enable in production."
  type        = bool
  default     = false
}

variable "airbyte_rds_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Set to true for dev environments; false for production to prevent data loss."
  type        = bool
  default     = true
}

variable "airbyte_rds_deletion_protection" {
  description = "Enable RDS deletion protection on the Airbyte config database. Disable in dev; enable in production to prevent accidental deletion."
  type        = bool
  default     = false
}

variable "airbyte_s3_force_destroy" {
  description = "Allow Terraform to empty and destroy the Airbyte S3 bucket on destroy. Safe in dev; must be false in production."
  type        = bool
  default     = false
}

variable "airbyte_alb_allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the Airbyte ALB on ports 80 and 443. Passed directly to the airbyte module's allowed_cidr_blocks. Include the Client VPN client CIDR so VPN-connected users can access the Airbyte UI through the load balancer."
  type        = list(string)
  default     = []
}

variable "vpn_available" {
  description = "Whether the Client VPN endpoint and its security group are deployed in this environment. When false, no direct ingress rules are added to the Airbyte instance SG from the VPN. Set to false in environments where the VPN has not yet been provisioned."
  type        = bool
  default     = false
}

variable "lakeformation_terraform_role_name" {
  description = "Name of the IAM role used by Terraform to manage this stack. Registered as a Lake Formation admin so Terraform retains the ability to manage LF resources after location registration."
  type        = string
  default     = "region-20-terraform-execution-role"
}

variable "lakeformation_admin_arns" {
  description = "Additional IAM principal ARNs (roles or users) to grant Lake Formation admin rights beyond the Terraform execution role. Useful for granting data platform team members LF admin access."
  type        = list(string)
  default     = []
}

variable "lakeformation_de_role_arns" {
  description = "ARNs of Data Engineer SSO roles to grant Lake Formation data permissions on bronze and silver databases. Permissions at the table level are controlled by lakeformation_de_table_permissions."
  type        = list(string)
  default     = []
}

variable "lakeformation_de_database_permissions" {
  description = "Lake Formation database-level permissions granted to the Data Engineer role on bronze and silver. Defaults to DESCRIBE only. Add DROP in dev to allow cleanup of test databases — remove before replicating to stg/prod."
  type        = list(string)
  default     = ["DESCRIBE"]
}

variable "lakeformation_de_table_permissions" {
  description = "Lake Formation table-level permissions granted to the Data Engineer role on bronze and silver. Defaults to read-only. Add DROP in dev to allow cleanup of test tables — remove before replicating to stg/prod."
  type        = list(string)
  default     = ["SELECT", "DESCRIBE"]
}

variable "oci_bastion_host" {
  type        = string
  description = "OCI bastion host to forward traffic to the Oracle DB"
}

variable "glue_connect20_crawler_schedule" {
  description = "AWS cron expression for the Connect20 Glue crawler nightly run (cron(0 3 * * ? *) -  9 PM CST) - 3 AM UTC). Set to null to disable scheduled runs."
  type        = string
  default     = "cron(0 3 * * ? *)"
}