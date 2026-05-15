# Terraform Networking Stack

This stack deploys the Region 20 VPC networking layer into a target AWS account using cross-account role assumption. It calls the `terraform/modules/networking` module to provision a VPC with public and private subnets across three availability zones, an Internet Gateway, NAT Gateways (single for dev, one-per-AZ for prod), an S3 Gateway VPC endpoint, five interface VPC endpoints, and VPC Flow Logs stored in a KMS-encrypted S3 bucket. State is stored in the shared `region-20-tf-state` S3 bucket using Terraform workspaces keyed by environment name.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.44.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_networking"></a> [networking](#module\_networking) | ../modules/networking | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the target account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_azs"></a> [azs](#input\_azs) | List of availability zone names to deploy subnets into | `list(string)` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name to be appended to all resources as prefix | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Whether to create the aws\_flow\_log resource for this VPC. Set false to skip flow log creation entirely (e.g., in non-production environments). | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_flow_log_bucket_arn"></a> [flow\_log\_bucket\_arn](#input\_flow\_log\_bucket\_arn) | ARN of the centralized S3 bucket in the audit account that receives VPC Flow Logs from this VPC | `string` | n/a | yes |
| <a name="input_flow_log_file_format"></a> [flow\_log\_file\_format](#input\_flow\_log\_file\_format) | Log file format delivered to S3. parquet is ~70% smaller than plain-text and reduces Athena scan cost via columnar compression. | `string` | `"plain-text"` | no |
| <a name="input_flow_log_hive_compatible_partitions"></a> [flow\_log\_hive\_compatible\_partitions](#input\_flow\_log\_hive\_compatible\_partitions) | Whether to use Hive-compatible S3 prefixes (e.g., year=2026/month=05/) so Athena can prune partitions during query. | `bool` | `false` | no |
| <a name="input_flow_log_per_hour_partition"></a> [flow\_log\_per\_hour\_partition](#input\_flow\_log\_per\_hour\_partition) | Whether to partition log objects per hour (in addition to per day). Useful at large volumes for finer Athena partition pruning. | `bool` | `false` | no |
| <a name="input_flow_log_traffic_type"></a> [flow\_log\_traffic\_type](#input\_flow\_log\_traffic\_type) | Type of traffic captured by the VPC flow log. ACCEPT logs only allowed traffic, REJECT logs only denied traffic (cheapest, security-focused), ALL logs every flow. | `string` | `"ALL"` | no |
| <a name="input_one_nat_gateway_per_az"></a> [one\_nat\_gateway\_per\_az](#input\_one\_nat\_gateway\_per\_az) | Provision one NAT Gateway per availability zone for HA; mutually exclusive with single\_nat\_gateway | `bool` | n/a | yes |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | List of CIDR blocks for private subnets; must have the same length as azs | `list(string)` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | List of CIDR blocks for public subnets; must have the same length as azs | `list(string)` | n/a | yes |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Provision a single shared NAT Gateway rather than one per AZ; mutually exclusive with one\_nat\_gateway\_per\_az | `bool` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | Primary IPv4 CIDR block for the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_caller_identity"></a> [aws\_caller\_identity](#output\_aws\_caller\_identity) | AWS caller identity information, or null when the stack is disabled (create = false) |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | ID of the aws\_flow\_log resource, or null when the stack is disabled (create = false) |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Map of endpoint key to VPC endpoint ID for each interface endpoint, or null when the stack is disabled (create = false) |
| <a name="output_interface_endpoint_security_group_id"></a> [interface\_endpoint\_security\_group\_id](#output\_interface\_endpoint\_security\_group\_id) | ID of the security group attached to all interface VPC endpoints, or null when the stack is disabled (create = false) |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | ID of the Internet Gateway, or null when the stack is disabled (create = false) |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | List of IDs of the NAT Gateways, or null when the stack is disabled (create = false) |
| <a name="output_private_route_table_ids"></a> [private\_route\_table\_ids](#output\_private\_route\_table\_ids) | List of IDs of the private route tables, or null when the stack is disabled (create = false) |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of IDs of the private subnets, or null when the stack is disabled (create = false) |
| <a name="output_public_route_table_ids"></a> [public\_route\_table\_ids](#output\_public\_route\_table\_ids) | List of IDs of the public route tables, or null when the stack is disabled (create = false) |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of IDs of the public subnets, or null when the stack is disabled (create = false) |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | Primary CIDR block of the VPC, or null when the stack is disabled (create = false) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC, or null when the stack is disabled (create = false) |
<!-- END_TF_DOCS -->
