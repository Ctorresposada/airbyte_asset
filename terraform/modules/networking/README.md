# Terraform Networking Module

This module provisions a complete VPC networking layer for a single environment: a VPC with public and private subnets spread across multiple availability zones, an Internet Gateway, NAT Gateways (single shared or one-per-AZ), an S3 Gateway VPC endpoint (free), five interface VPC endpoints (Secrets Manager, Glue, Step Functions, Redshift, KMS) backed by a dedicated security group, and VPC Flow Logs delivered to a KMS-encrypted S3 bucket with configurable lifecycle expiry.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | ~> 5.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_security_group.interface_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azs"></a> [azs](#input\_azs) | List of availability zone names to deploy subnets into | `list(string)` | n/a | yes |
| <a name="input_flow_log_bucket_arn"></a> [flow\_log\_bucket\_arn](#input\_flow\_log\_bucket\_arn) | ARN of the centralized S3 bucket in the audit account that receives VPC Flow Logs from this VPC | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name prefix applied to all resources created by this module | `string` | n/a | yes |
| <a name="input_one_nat_gateway_per_az"></a> [one\_nat\_gateway\_per\_az](#input\_one\_nat\_gateway\_per\_az) | Provision one NAT Gateway per availability zone for HA; mutually exclusive with single\_nat\_gateway | `bool` | `true` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | List of CIDR blocks for private subnets; must have the same length as azs | `list(string)` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | List of CIDR blocks for public subnets; must have the same length as azs | `list(string)` | n/a | yes |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Provision a single shared NAT Gateway rather than one per AZ; mutually exclusive with one\_nat\_gateway\_per\_az | `bool` | `false` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Primary IPv4 CIDR block for the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | ID of the aws\_flow\_log resource |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Map of endpoint key to VPC endpoint ID for each interface endpoint |
| <a name="output_interface_endpoint_security_group_id"></a> [interface\_endpoint\_security\_group\_id](#output\_interface\_endpoint\_security\_group\_id) | ID of the security group attached to all interface VPC endpoints |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID of the Internet Gateway |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of IDs of the NAT Gateways |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | List of IDs of the private route tables |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of IDs of the private subnets |
| <a name="output_public_route_table_ids"></a> [public\_route\_table\_ids](#output\_public\_route\_table\_ids) | List of IDs of the public route tables |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of IDs of the public subnets |
| <a name="output_s3_gateway_endpoint_id"></a> [s3\_gateway\_endpoint\_id](#output\_s3\_gateway\_endpoint\_id) | ID of the S3 Gateway VPC endpoint |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | Primary CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
<!-- END_TF_DOCS -->
