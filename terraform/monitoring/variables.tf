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
  description = "Company name prefix used in resource names"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "enable_airbyte_monitoring" {
  description = "Enable CloudWatch alarms and dashboard panels for the self-hosted Airbyte EC2 instance and RDS database."
  type        = bool
  default     = false
}

variable "enable_dbt_ecs_monitoring" {
  description = "Enable CloudWatch alarms and dashboard panels for the self-hosted dbt Core ECS Fargate cluster."
  type        = bool
  default     = false
}

variable "warning_emails" {
  description = "Email addresses subscribed to the Warning SNS topic."
  type        = list(string)
  default     = []
}

variable "critical_emails" {
  description = "Email addresses subscribed to the Critical SNS topic."
  type        = list(string)
  default     = []
}

variable "redshift_compute_seconds_threshold" {
  description = "Hourly ComputeSeconds sum threshold for the Redshift compute usage alarm."
  type        = number
  default     = 7200
}

variable "athena_log_group_name" {
  description = "CloudWatch log group name for Athena query logs. Used for the failed-queries metric filter."
  type        = string
  default     = "/aws/athena/queries"
}

