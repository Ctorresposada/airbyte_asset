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
  description = "Common tags to apply to all resources"
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
