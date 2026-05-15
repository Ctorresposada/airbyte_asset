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

variable "bucket_name" {
  description = "Name of the S3 raw/landing zone bucket for files"
  type        = string
  default     = "escr20-landing-zone"
}

variable "tags" {
  description = "Common tags to apply to S3 buckets"
  type        = map(string)
  default     = {}
}
