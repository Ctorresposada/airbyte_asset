variable "name" {
  description = "Name prefix applied to all resources created by this module"
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

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs must contain one entry per availability zone in azs."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets; must have the same length as azs"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs must contain one entry per availability zone in azs."
  }
}

variable "single_nat_gateway" {
  description = "Provision a single shared NAT Gateway rather than one per AZ; mutually exclusive with one_nat_gateway_per_az"
  type        = bool
  default     = false

  validation {
    condition     = !(var.single_nat_gateway && var.one_nat_gateway_per_az)
    error_message = "single_nat_gateway and one_nat_gateway_per_az cannot both be true."
  }
}

variable "one_nat_gateway_per_az" {
  description = "Provision one NAT Gateway per availability zone for HA; mutually exclusive with single_nat_gateway"
  type        = bool
  default     = true
}

variable "flow_log_bucket_arn" {
  description = "ARN of the centralized S3 bucket in the audit account that receives VPC Flow Logs from this VPC"
  type        = string
}
