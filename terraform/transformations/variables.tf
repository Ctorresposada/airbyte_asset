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
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN and resource ARN conditions"
  type        = string
}

variable "ecr_repository_url" {
  description = "Full URL of the shared dbt Core ECR repository in the service account (e.g. <account>.dkr.ecr.us-east-1.amazonaws.com/<name>). Sourced from the service-account stack's ecr_repository_url output. Terraform creates the initial task definition revision with <ecr_repository_url>:initial; the dbt build pipeline registers subsequent revisions with immutable build tags via AWS CLI."
  type        = string

  validation {
    condition     = length(var.ecr_repository_url) > 0
    error_message = "ecr_repository_url must be a non-empty string."
  }
}

variable "ecr_repository_arn" {
  description = "ARN of the shared dbt Core ECR repository in the service account. Sourced from the service-account stack's ecr_repository_arn output. Used to scope the ECS task execution role's ECR pull statement to this repository only."
  type        = string

  validation {
    condition     = length(var.ecr_repository_arn) > 0
    error_message = "ecr_repository_arn must be a non-empty string."
  }
}

variable "enable_dbt_task" {
  description = "Whether to enable the dbt Core ECS task definition"
  type        = bool
  default     = true
}

variable "dbt_task_cpu" {
  description = "Fargate task-level CPU units for the dbt Core task. Must be a valid Fargate CPU value. 1024 units = 1 vCPU."
  type        = number
  default     = 1024

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.dbt_task_cpu)
    error_message = "dbt_task_cpu must be a valid Fargate CPU value: 256, 512, 1024, 2048, 4096, 8192, or 16384."
  }
}

variable "dbt_task_memory" {
  description = "Fargate task-level memory (MiB) for the dbt Core task. Must be a valid Fargate memory value compatible with the chosen CPU. 2048 MiB = 2 GB."
  type        = number
  default     = 2048

  validation {
    condition     = var.dbt_task_memory >= 512 && var.dbt_task_memory % 512 == 0
    error_message = "dbt_task_memory must be at least 512 MiB and a multiple of 512."
  }
}

variable "dbt_log_retention_days" {
  description = "Retention in days for the dbt Core CloudWatch log groups (ECS task logs and cluster logs). CloudWatch storage cost grows linearly with this value; dev should keep it short."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653], var.dbt_log_retention_days)
    error_message = "dbt_log_retention_days must be one of the values CloudWatch Logs accepts: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "kms_key_users" {
  description = "List of IAM principal ARNs (roles / users) permitted to use the transformations KMS CMK for read/write operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey). An empty list means no principals other than the account root and the ECS task role (granted via its inline policy) can use the key — safe default for first apply."
  type        = list(string)
  default     = []
}

variable "redshift_db" {
  description = "Redshift Serverless database dbt connects to. Must match the database provisioned in the warehouse stack."
  type        = string
  default     = "gold"
}

variable "redshift_schema" {
  description = "dbt target schema inside the Redshift database. The dbt_service user has USAGE+CREATE+ALL on the gold schema — that is the correct target for dbt output models."
  type        = string
  default     = "gold"
}

variable "redshift_user" {
  description = "Redshift database user dbt authenticates as via IAM-brokered credentials. Must match the user created in the warehouse stack (dbt_redshift_user variable)."
  type        = string
  default     = "dbt_service"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
