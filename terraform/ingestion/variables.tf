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
  description = "Map of S3 buckets to create"
  type = map(object({
    name               = string
    layer              = string
    transition_ia      = number
    transition_glacier = number
    expiration_days    = number
  }))
  default = {
    raw = {
      name               = "escr20-landing-zone"
      layer              = "raw"
      transition_ia      = 90
      transition_glacier = 365
      expiration_days    = 2555
    }
    bronze = {
      name               = "escr20-bronze"
      layer              = "bronze"
      transition_ia      = 90
      transition_glacier = 365
      expiration_days    = 2555
    }
    silver = {
      name               = "escr20-silver"
      layer              = "silver"
      transition_ia      = 180
      transition_glacier = 365
      expiration_days    = 2555
    }
  }
}

variable "tags" {
  description = "Common tags to apply to S3 buckets"
  type        = map(string)
  default     = {}
}
