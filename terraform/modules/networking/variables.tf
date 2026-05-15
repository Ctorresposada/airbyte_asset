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

variable "enable_flow_logs" {
  description = "Whether to create the aws_flow_log resource for this VPC. Set false to skip flow log creation entirely (e.g., in non-production environments)."
  type        = bool
  default     = true
}

variable "flow_log_traffic_type" {
  description = "Type of traffic captured by the VPC flow log. ACCEPT logs only allowed traffic, REJECT logs only denied traffic (cheapest, security-focused), ALL logs every flow."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be one of: ACCEPT, REJECT, ALL."
  }
}

variable "flow_log_file_format" {
  description = "Log file format delivered to S3. parquet is ~70% smaller than plain-text and reduces Athena scan cost via columnar compression."
  type        = string
  default     = "plain-text"

  validation {
    condition     = contains(["plain-text", "parquet"], var.flow_log_file_format)
    error_message = "flow_log_file_format must be one of: plain-text, parquet."
  }
}

variable "flow_log_hive_compatible_partitions" {
  description = "Whether to use Hive-compatible S3 prefixes (e.g., year=2026/month=05/) so Athena can prune partitions during query."
  type        = bool
  default     = false
}

variable "flow_log_per_hour_partition" {
  description = "Whether to partition log objects per hour (in addition to per day). Useful at large volumes for finer Athena partition pruning."
  type        = bool
  default     = false
}
