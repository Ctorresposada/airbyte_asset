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

output "aws_caller_identity" {
  description = "AWS caller identity information, or null when the stack is disabled (create = false)"
  value       = try(data.aws_caller_identity.this[0], null)
}

output "flow_log_id" {
  description = "ID of the aws_flow_log resource, or null when the stack is disabled (create = false)"
  value       = try(module.networking[0].flow_log_id, null)
}

output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN endpoint, or null when Client VPN is disabled"
  value       = try(aws_ec2_client_vpn_endpoint.this[0].id, null)
}

output "client_vpn_saml_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the Client VPN SAML metadata document; populate this secret before enabling the VPN"
  value       = try(aws_secretsmanager_secret.client_vpn_saml[0].arn, null)
}
