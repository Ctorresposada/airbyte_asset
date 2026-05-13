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

variable "company_name" {
  description = "Name to be appended to all resources as prefix"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

variable "vpc_cidr" {
  description = "Primary IPv4 CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zone names to deploy subnets into"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets; must have the same length as azs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets; must have the same length as azs"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Provision a single shared NAT Gateway rather than one per AZ; mutually exclusive with one_nat_gateway_per_az"
  type        = bool
}

variable "one_nat_gateway_per_az" {
  description = "Provision one NAT Gateway per availability zone for HA; mutually exclusive with single_nat_gateway"
  type        = bool
}

variable "flow_log_bucket_arn" {
  description = "ARN of the centralized S3 bucket in the audit account that receives VPC Flow Logs from this VPC"
  type        = string
}
