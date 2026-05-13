variable "environment" {
  description = "Target deployment environment"
  type        = string
}

variable "aws_region" {
  description = "Target deployment region"
  type        = string
}

variable "team" {
  description = "Team that manages this project"
  type        = string
}

variable "company_name" {
  description = "Name to be appended to all resources as prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the audit account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "source_account_ids" {
  description = "List of AWS account IDs permitted to deliver VPC Flow Logs to the centralized audit bucket"
  type        = list(string)
}

variable "flow_log_bucket_name" {
  description = "Deterministic name for the centralized VPC Flow Logs S3 bucket in the audit account"
  type        = string
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC Flow Log objects in S3 before expiration; audit logs are typically retained longer than per-env logs"
  type        = number
  default     = 365
}

variable "flow_log_bucket_force_destroy" {
  description = "Allow Terraform to destroy the Flow Log S3 bucket even when it contains objects; set true only for non-production environments"
  type        = bool
  default     = false
}
