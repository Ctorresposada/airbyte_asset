# Airbyte Asset — Root Module Variables
# These are the inputs required to deploy Airbyte into any AWS account.

# ---------------------------------------------------------------------------
# Deployment variant
# ---------------------------------------------------------------------------

variable "deployment_type" {
  description = "Deployment variant. 'ec2' runs Airbyte on an EC2 ASG with abctl (~$150/mo). 'eks' runs Airbyte on EKS via Helm (~$300-500/mo). Valid values: ec2, eks."
  type        = string
  default     = "ec2"

  validation {
    condition     = contains(["ec2", "eks"], var.deployment_type)
    error_message = "deployment_type must be 'ec2' or 'eks'."
  }
}

# ---------------------------------------------------------------------------
# AWS
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

# ---------------------------------------------------------------------------
# Project identification
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Name for the Airbyte deployment. Used as a prefix for all resources (e.g. 'acme-airbyte')."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. 'dev', 'staging', 'prod'). Appended to the project name."
  type        = string
}

# ---------------------------------------------------------------------------
# Networking (provided by the customer)
# ---------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the existing VPC where Airbyte will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EC2 ASG and RDS. Must span at least 2 AZs for RDS."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB. Required when create_alb = true."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# DNS & Certificate
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "FQDN for the Airbyte console (e.g. 'airbyte.example.com'). If provided with route53_zone_id, the module creates an ACM certificate and Route53 A record automatically."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record creation and ACM certificate validation."
  type        = string
  default     = ""
}

variable "alb_certificate_arn" {
  description = "ARN of an existing ACM certificate for the ALB. If empty and domain_name is set, a certificate is created automatically."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

variable "create_alb" {
  description = "Whether to create an Application Load Balancer for the Airbyte webapp."
  type        = bool
  default     = true
}

variable "alb_internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)."
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitted to reach the ALB on ports 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type. m6a.2xlarge (8 vCPU / 32 GB) is the recommended minimum for running syncs."
  type        = string
  default     = "m6a.2xlarge"
}

variable "ami_architecture" {
  description = "AMI architecture for Amazon Linux 2023 lookup. Use 'arm64' for Graviton instances (m6g/m7g) or 'x86_64' for Intel/AMD."
  type        = string
  default     = "arm64"
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 50
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------

variable "rds_instance_class" {
  description = "RDS instance class for the Airbyte PostgreSQL config database."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS. Recommended for production."
  type        = bool
  default     = false
}

variable "rds_backup_retention_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection. Recommended for production."
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
  description = "CloudWatch log retention in days."
  type        = number
  default     = 90
}

variable "s3_force_destroy" {
  description = "Allow Terraform to destroy the S3 bucket even when it contains objects. Only for dev/staging."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# EKS (only used when deployment_type = "eks")
# ---------------------------------------------------------------------------

variable "eks_cluster_ready" {
  description = "Set to true on Pass 2 of an EKS deployment, after the cluster has been created. Controls whether the Helm/kubernetes providers attempt to connect to the cluster."
  type        = bool
  default     = false
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS managed node group."
  type        = string
  default     = "m6a.xlarge"
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the EKS managed node group."
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in the EKS managed node group."
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in the EKS managed node group."
  type        = number
  default     = 4
}

variable "eks_airbyte_chart_version" {
  description = "Airbyte Helm chart version to deploy on EKS."
  type        = string
  default     = "2.1.0"
}
