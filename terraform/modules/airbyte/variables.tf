# Module: airbyte-compute
# Input variable definitions for the Airbyte EC2 ASG compute module.

# ---------------------------------------------------------------------------
# Required variables (no defaults)
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to every resource created by this module."
  type        = string
}

variable "compute_name" {
  description = "Name to be added to compute resources only."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC into which Airbyte resources are deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the Auto Scaling Group instances and the RDS DB subnet group."
  type        = list(string)
}

variable "ami_id" {
  description = "ID of the Docker-enabled AMI used for the Airbyte EC2 instance. Amazon Linux 2023 is recommended; Docker will be installed via user-data if not pre-baked."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt EBS volumes, RDS storage, S3 objects, Secrets Manager secrets, and the CloudWatch log group."
  type        = string
}

# ---------------------------------------------------------------------------
# ALB variables
# ---------------------------------------------------------------------------

variable "create_alb" {
  description = "Whether to create an internal Application Load Balancer for the Airbyte webapp. Set to false to run without an ALB (access via SSM port forwarding or a future VPN). Defaults to false."
  type        = bool
  default     = false
}

variable "alb_subnet_ids" {
  description = "List of private subnet IDs for the internal Application Load Balancer. Required when create_alb = true; ignored otherwise."
  type        = list(string)
  default     = []
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener. Required when create_alb = true."
  type        = string
  default     = ""

  validation {
    condition     = !var.create_alb || (var.create_alb && var.alb_certificate_arn != "")
    error_message = "alb_certificate_arn must be set when create_alb = true."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the ALB on port 443 (and port 80 for HTTPS redirect). Typically the VPC CIDR or a bastion range. Required when create_alb = true; ignored otherwise."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# RDS variables
# ---------------------------------------------------------------------------

variable "rds_db_name" {
  description = "Name of the PostgreSQL database used by Airbyte for configuration storage."
  type        = string
  default     = "db-airbyte"
}

variable "rds_temporal_db_name" {
  description = "Name of the PostgreSQL database used by Temporal (workflow engine). Resides on the same RDS instance as rds_db_name."
  type        = string
  default     = "temporal"
}

variable "rds_username" {
  description = "PostgreSQL username for the Airbyte application user."
  type        = string
  default     = "airbyte"
}

variable "rds_instance_class" {
  description = "RDS instance class for the Airbyte PostgreSQL config database. db.t3.micro is sufficient at small scale. Use db.t3.small or larger for production with many connectors and high sync frequency."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for the RDS instance. Doubles cost but provides automatic failover. Recommended for production."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Set to false for production environments to prevent accidental data loss."
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection. Recommended for production. Must be disabled before destroy."
  type        = bool
  default     = false
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain automated RDS backups. Set to 0 to disable backups (not recommended)."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Optional variables (with defaults)
# ---------------------------------------------------------------------------

variable "create" {
  description = "When false, no resources are created. Set to false in a tfvars file to soft-delete everything this module manages while preserving Terraform state."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for the Airbyte ASG. m6a.xlarge (4 vCPU, 16 GB) is the minimum viable size. Use m6a.2xlarge for production with more than 10 connectors or sub-hourly sync frequency."
  type        = string
  default     = "m6a.xlarge"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log events for the Airbyte log group. Defaults to 365 to satisfy CKV_AWS_338; override to a shorter period for dev/staging."
  type        = number
  default     = 365
}

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy the Airbyte S3 bucket even when it contains objects. Set to true only for dev/staging where data loss on destroy is acceptable."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
