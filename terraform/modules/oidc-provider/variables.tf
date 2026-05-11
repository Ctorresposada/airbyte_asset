variable "create_oidc_provider" {
  description = "Whether to create the OIDC provider for GitHub Actions"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of an existing OIDC provider to use instead of creating a new one"
  type        = string
  default     = null
}

variable "role_name" {
  description = "The name of the IAM role to be created for GitHub Actions"
  type        = string
}

variable "role_description" {
  description = "The description of the IAM role"
  type        = string
  default     = "IAM role for GitHub Actions OIDC authentication"
}

variable "max_session_duration" {
  description = "Maximum session duration (in seconds) for the IAM role"
  type        = number
  default     = 3600
  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 (1 hour) and 43200 (12 hours) seconds."
  }
}

variable "github_repositories" {
  description = "List of GitHub repositories (format: 'owner/repo') allowed to assume the role. Cannot be used with github_organization."
  type        = list(string)
  default     = []
}

variable "github_organization" {
  description = "GitHub organization allowed to assume the role (all repos in the org). Cannot be used with github_repositories."
  type        = string
  default     = null
}

variable "thumbprint_list" {
  description = "List of server certificate thumbprints for GitHub OIDC provider"
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

variable "attach_custom_policy" {
  description = "Whether to attach a custom IAM policy to the role"
  type        = bool
  default     = false
}

variable "custom_policy_arn" {
  description = "ARN of a custom IAM policy to attach to the role"
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "attach_inline_policy" {
  description = "Whether to attach an inline policy to the role"
  type        = bool
  default     = false
}

variable "inline_policy_json" {
  description = "JSON-formatted inline policy to attach to the role"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
