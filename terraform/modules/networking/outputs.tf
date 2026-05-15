output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_route_table_ids" {
  description = "List of IDs of the public route tables"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value       = module.vpc.private_route_table_ids
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "interface_endpoint_security_group_id" {
  description = "ID of the security group attached to all interface VPC endpoints"
  value       = aws_security_group.interface_endpoints.id
}

output "interface_endpoint_ids" {
  description = "Map of endpoint key to VPC endpoint ID for each interface endpoint"
  value       = module.endpoints.endpoints
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint"
  value       = module.endpoints.endpoints["s3"].id
}

output "flow_log_id" {
  description = "ID of the aws_flow_log resource, or null when flow logs are disabled (enable_flow_logs = false)"
  value       = try(aws_flow_log.this[0].id, null)
}
