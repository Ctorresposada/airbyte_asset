# Module: airbyte
# Input variable definitions for the self-hosted Airbyte deployment module.

# ---------------------------------------------------------------------------
# Required variables (no defaults)
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix applied to every resource created by this module (e.g. 'acme-airbyte-dev')."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC into which Airbyte resources are deployed."
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must start with 'vpc-'."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the Auto Scaling Group instances and the RDS DB subnet group."
  type        = list(string)
}

variable "ami_id" {
  description = "ID of the Docker-enabled AMI used for the Airbyte EC2 instance. Amazon Linux 2023 is recommended; Docker will be installed via user-data if not pre-baked."
  type        = string
}

# ---------------------------------------------------------------------------
# DNS & Certificate variables
# ---------------------------------------------------------------------------

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for creating the Airbyte DNS record and ACM certificate validation. Required when create_alb = true."
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Fully qualified domain name for the Airbyte console (e.g. 'airbyte.example.com'). Used for the Route53 A record and ACM certificate. Required when create_alb = true."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# ALB variables
# ---------------------------------------------------------------------------

variable "create_alb" {
  description = "Whether to create an Application Load Balancer for the Airbyte webapp. When true, also creates an ACM certificate and Route53 record if domain_name and route53_zone_id are provided."
  type        = bool
  default     = true
}

variable "alb_subnet_ids" {
  description = "List of subnet IDs for the Application Load Balancer. Use public subnets when alb_internal = false; private subnets otherwise. Required when create_alb = true."
  type        = list(string)
  default     = []
}

variable "alb_internal" {
  description = "Whether the Application Load Balancer is internal (true) or internet-facing (false). Set to false to expose Airbyte publicly via an internet-facing ALB."
  type        = bool
  default     = false
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener. If empty and domain_name is set, the module creates and validates an ACM certificate automatically."
  type        = string
  default     = ""
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB. Recommended for production. Must be disabled before the ALB can be destroyed."
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs. When non-empty, ALB access logging is enabled. The bucket must already exist with the correct ELB service principal policy."
  type        = string
  default     = ""
}

variable "alb_access_logs_prefix" {
  description = "S3 key prefix for ALB access logs. Only used when alb_access_logs_bucket is set."
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the ALB on port 443 (and port 80 for HTTPS redirect). Defaults to 0.0.0.0/0 for internet-facing ALBs. Restrict for internal deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# RDS variables
# ---------------------------------------------------------------------------

variable "rds_db_name" {
  description = "Name of the PostgreSQL database used by Airbyte for configuration storage."
  type        = string
  default     = "airbyte"
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

  validation {
    condition     = var.rds_backup_retention_days >= 0 && var.rds_backup_retention_days <= 35
    error_message = "rds_backup_retention_days must be between 0 and 35."
  }
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
  description = "EC2 instance type for the Airbyte ASG. m6a.2xlarge (8 vCPU, 32 GB) is the recommended minimum. Replication jobs request ~9 CPU per sync; xlarge (4 vCPU) cannot run even a single sync."
  type        = string
  default     = "m6a.2xlarge"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log events for the Airbyte log group. Defaults to 365 to satisfy CKV_AWS_338; override to a shorter period for dev/staging."
  type        = number
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value accepted by CloudWatch (0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, or 3653)."
  }
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

variable "ebs_volume_size" {
  description = "Size (in GB) of the root EBS volume for the Airbyte EC2 instance. 50 GB is the minimum; increase for high-volume syncs."
  type        = number
  default     = 50

  validation {
    condition     = var.ebs_volume_size >= 20
    error_message = "ebs_volume_size must be at least 20 GB."
  }
}
