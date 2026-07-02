# Module: airbyte-eks — Variables
# Self-hosted Airbyte on EKS via Helm.

# ---------------------------------------------------------------------------
# Deployment phase
# ---------------------------------------------------------------------------

variable "helm_enabled" {
  description = "Set to true on Pass 2 (after the EKS cluster exists) to install Helm releases. False on Pass 1 so Helm releases are skipped entirely and the provider does not attempt to connect."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for all resources (e.g. 'acme-airbyte-dev')."
  type        = string
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the existing VPC."
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must start with 'vpc-'."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS node group and RDS. Must span at least 2 AZs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB (controller-managed)."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# DNS & Certificate
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "FQDN for the Airbyte console. If provided with route53_zone_id, the module creates an ACM certificate automatically."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for ACM certificate validation and ExternalDNS."
  type        = string
  default     = ""
}

variable "alb_certificate_arn" {
  description = "ARN of an existing ACM certificate. If empty and domain_name is set, a certificate is created automatically."
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the ALB on ports 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can reach the EKS Kubernetes API server public endpoint. Restrict to your IP or CI/CD runner CIDRs in production. Does not affect the Airbyte web console (ALB)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group. m6a.2xlarge (8 vCPU / 32 GB) is the recommended minimum — Airbyte replication pods request 4 vCPU each and the platform consumes ~4-5 vCPU, leaving xlarge nodes unable to schedule syncs."
  type        = string
  default     = "m6a.2xlarge"
}

variable "node_desired_size" {
  description = "Desired number of nodes in the EKS managed node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the EKS managed node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS managed node group."
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "airbyte_chart_version" {
  description = "Airbyte Helm chart version to deploy."
  type        = string
  default     = "1.9.2"
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "rds_db_name" {
  description = "Name of the PostgreSQL database used by Airbyte for configuration storage."
  type        = string
  default     = "airbyte"
}

variable "rds_temporal_db_name" {
  description = "Name of the PostgreSQL database used by Temporal. Resides on the same RDS instance."
  type        = string
  default     = "temporal"
}

variable "rds_username" {
  description = "PostgreSQL username for the Airbyte application user."
  type        = string
  default     = "airbyte"
}

variable "rds_instance_class" {
  description = "RDS instance class for the Airbyte PostgreSQL config database."
  type        = string
  default     = "db.t3.small"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS. Defaults to true for EKS (HA deployment)."
  type        = bool
  default     = true
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_days >= 0 && var.rds_backup_retention_days <= 35
    error_message = "rds_backup_retention_days must be between 0 and 35."
  }
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Set to false for production."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log events. Defaults to 365 to satisfy CKV_AWS_338; override to a shorter period for dev/staging."
  type        = number
  default     = 365

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value accepted by CloudWatch (0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, or 3653)."
  }
}

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy the S3 bucket even when it contains objects. Only for dev/staging."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
