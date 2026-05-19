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
