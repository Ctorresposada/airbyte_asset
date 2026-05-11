variable "s3_bucket_name" {
  description = "The name of the S3 bucket for storing Terraform state"
  type        = string
}

variable "kms_key_alias" {
  description = "The alias for the KMS key used for Terraform state encryption"
  type        = string
}

variable "kms_enable_default_policy" {
  description = "Whether to enable the default policy for the KMS key"
  type        = bool
  default     = true
}

variable "kms_key_administrators" {
  description = "The list of IAM users and roles allowed to administer the KMS key"
  type        = list(string)
  default     = []
}

variable "kms_key_users" {
  description = "The list of IAM users and roles allowed to use the KMS key"
  type        = list(string)
  default     = []
}

variable "create_state_management_iam_policy" {
  description = "Whether to create the IAM policy"
  type        = bool
  default     = true
}

variable "state_management_iam_policy_name" {
  description = "The name of the IAM policy"
  type        = string
  default     = "TerraformStateManagement"
}

variable "state_management_iam_policy_description" {
  description = "The description of the IAM policy"
  type        = string
  default     = "Terraform State Management policy"
}
