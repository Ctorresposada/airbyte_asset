output "vpc_id" {
  description = "ID of the VPC, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].vpc_id, null)
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].vpc_cidr_block, null)
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].public_subnet_ids, null)
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].private_subnet_ids, null)
}

output "public_route_table_ids" {
  description = "List of IDs of the public route tables, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].public_route_table_ids, null)
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].private_route_table_ids, null)
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].nat_gateway_ids, null)
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].internet_gateway_id, null)
}

output "interface_endpoint_security_group_id" {
  description = "ID of the security group attached to all interface VPC endpoints, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].interface_endpoint_security_group_id, null)
}

output "interface_endpoint_ids" {
  description = "Map of endpoint key to VPC endpoint ID for each interface endpoint, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].interface_endpoint_ids, null)
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].s3_gateway_endpoint_id, null)
}

output "flow_log_id" {
  description = "ID of the aws_flow_log resource, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].flow_log_id, null)
}
