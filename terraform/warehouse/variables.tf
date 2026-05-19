variable "create" {
  description = "Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code."
  type        = bool
  default     = true
}

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
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "redshift_key_users" {
  description = "List of IAM principal ARNs (roles / users) permitted to use the Redshift KMS CMK for read/write operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey). An empty list means no principals other than the account root can use the key — safe default for first apply."
  type        = list(string)
  default     = []
}
