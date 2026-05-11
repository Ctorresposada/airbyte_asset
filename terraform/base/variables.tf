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

variable "company_name" {
  description = "Name to be appended to all resources as prefix"
  type        = string
}

