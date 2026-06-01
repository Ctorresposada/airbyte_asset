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
  description = "Target deployment region. IAM Identity Center is region-pinned to the IDC home region; this should match it."
  type        = string
}

variable "team" {
  description = "Team that manages this project"
  type        = string
}

variable "account_id" {
  description = "AWS account ID where the stack runs. For the security stack this is the IAM Identity Center delegated administrator account, not the IDC owner (management) account."
  type        = string
}

variable "instance_arn" {
  description = "ARN of the IAM Identity Center (SSO) instance under which permission sets and account assignments are managed."
  type        = string
}

variable "identity_store_id" {
  description = "Identifier of the Identity Store (e.g. d-xxxxxxxxxx) backing the IAM Identity Center instance."
  type        = string
}

variable "data_lake_group" {
  description = "Identity Store group representing Caylent members working on the Data Lake. group_id is required for the import; display_name and description must match the live values exactly to avoid drift."
  type = object({
    group_id     = string
    display_name = string
    description  = string
  })
}

variable "data_engineer_prod_permission_set" {
  description = "Configuration attributes of the DataEngineer_Prod permission set in IAM Identity Center."
  type = object({
    name             = string
    description      = string
    session_duration = string
    managed_policies = list(string)
  })
}

variable "data_engineer_dev_permission_set" {
  description = "Configuration attributes of the DataEngineer_Dev permission set in IAM Identity Center."
  type = object({
    name             = string
    description      = string
    session_duration = string
    managed_policies = list(string)
  })
}

variable "data_engineer_account_assignments" {
  description = "Account assignments granting the Data-Lake-Caylent group access to target accounts. The map key (\"prod\" or \"dev\") must match the corresponding permission set resource key."
  type = map(object({
    aws_account_id = string
  }))
}
