variable "create" {
  description = "Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name for resource tagging. This stack runs in a single shared-services account, so the conventional value is 'shared'."
  type        = string
}

variable "aws_region" {
  description = "Target deployment region for the shared-services ECR repository and its KMS key."
  type        = string
  default     = "us-east-1"
}

variable "company_name" {
  description = "Name to be appended to all resources as prefix"
  type        = string
}

variable "team" {
  description = "Team that manages this stack"
  type        = string
}

variable "ecr_image_retention_count" {
  description = "Number of most-recent tagged images to retain in the dbt Core ECR repository before older tagged images are expired by the lifecycle policy."
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_image_retention_count >= 1
    error_message = "ecr_image_retention_count must be at least 1."
  }
}

variable "consumer_account_ids" {
  description = "AWS account IDs allowed to pull images from the shared dbt Core ECR repository. The repository policy grants the account roots cross-account pull, letting each account further delegate pull access via its own IAM policies. Defaults to the dev and prod workload accounts."
  type        = list(string)
  default     = ["784590287037", "029750300494"]

  validation {
    condition     = alltrue([for id in var.consumer_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "Each consumer_account_ids entry must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Additional tags to merge onto all resources"
  type        = map(string)
  default     = {}
}
