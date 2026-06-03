# Terraform Ingestion Stack

This stack provisions the AWS infrastructure for the Region 20 Data Lake ingestion layer: the S3 medallion storage (raw / bronze / silver), the Glue Catalog databases that sit on top of bronze and silver, the self-managed Airbyte compute platform that loads data into the lake, and the dedicated Airbyte Cloud IAM user with its credentials secret. It also wires up the cross-account replication policy that lets the Ascender source account write into the raw landing zone. State is stored in the shared `region-20-tf-state` S3 bucket under the `ingestion/terraform.tfstate` key, using Terraform workspaces keyed by environment name.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.46.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_airbyte"></a> [airbyte](#module\_airbyte) | ../modules/airbyte | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.gdrive_sync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_glue_catalog_database.databases](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_database) | resource |
| [aws_glue_crawler.crawlers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_crawler) | resource |
| [aws_glue_security_configuration.crawlers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_security_configuration) | resource |
| [aws_iam_access_key.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_policy.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.airbyte_instance_s3_bronze](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.gdrive_sync_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.gdrive_sync_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.glue_crawlers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.gdrive_sync_lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.gdrive_sync_scheduler_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.glue_crawlers_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.glue_crawlers_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.airbyte_instance_s3_bronze](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.gdrive_sync_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.glue_crawlers_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_kms_alias.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.glue_crawlers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.glue_crawlers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lakeformation_data_lake_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_data_lake_settings) | resource |
| [aws_lakeformation_permissions.airbyte_bronze_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.airbyte_bronze_location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_bronze_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_bronze_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_raw_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_raw_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_silver_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.de_silver_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.glue_crawlers_database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.glue_crawlers_location](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_resource.bronze](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_resource) | resource |
| [aws_lakeformation_resource.raw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_resource) | resource |
| [aws_lakeformation_resource.silver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_resource) | resource |
| [aws_lambda_function.gdrive_sync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_layer_version.gdrive_deps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_s3_bucket.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.raw_ascender_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.ascender_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.connect20_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.tea_prefix](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_scheduler_schedule.gdrive_sync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_secretsmanager_secret.airbyte_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.airbyte_google_drive_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.airbyte_oracle_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.gdrive_sa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.airbyte_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_policy.airbyte_google_drive_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_policy.airbyte_oracle_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_version.airbyte_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.gdrive_sa_placeholder](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_ssm_parameter.gdrive_sync_cursor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.airbyte_instance_to_oci](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.airbyte_instance_from_vpn_ui](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.airbyte_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.glue_crawler_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.glue_crawlers_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.glue_crawlers_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.glue_crawlers_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.raw_bucket_ascender_crr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.raw_bucket_connect20_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.raw_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.terraform_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_security_groups.client_vpn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_groups) | data source |
| [aws_ssm_parameter.al2023_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the target account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_airbyte_alb_allowed_cidr_blocks"></a> [airbyte\_alb\_allowed\_cidr\_blocks](#input\_airbyte\_alb\_allowed\_cidr\_blocks) | CIDR blocks permitted to reach the Airbyte ALB on ports 80 and 443. Passed directly to the airbyte module's allowed\_cidr\_blocks. Include the Client VPN client CIDR so VPN-connected users can access the Airbyte UI through the load balancer. | `list(string)` | `[]` | no |
| <a name="input_airbyte_instance_type"></a> [airbyte\_instance\_type](#input\_airbyte\_instance\_type) | EC2 instance type for the Airbyte ASG. Use m6a.xlarge for dev (minimum viable) and m6a.2xlarge for production. | `string` | `"m6a.2xlarge"` | no |
| <a name="input_airbyte_log_retention_days"></a> [airbyte\_log\_retention\_days](#input\_airbyte\_log\_retention\_days) | CloudWatch log retention in days for the Airbyte log group. Use 30 for dev to control cost; 365 for production. | `number` | `365` | no |
| <a name="input_airbyte_rds_deletion_protection"></a> [airbyte\_rds\_deletion\_protection](#input\_airbyte\_rds\_deletion\_protection) | Enable RDS deletion protection on the Airbyte config database. Disable in dev; enable in production to prevent accidental deletion. | `bool` | `false` | no |
| <a name="input_airbyte_rds_instance_class"></a> [airbyte\_rds\_instance\_class](#input\_airbyte\_rds\_instance\_class) | RDS instance class for the Airbyte PostgreSQL config database. db.t3.micro for dev; db.t3.small or larger for production. | `string` | `"db.t3.small"` | no |
| <a name="input_airbyte_rds_multi_az"></a> [airbyte\_rds\_multi\_az](#input\_airbyte\_rds\_multi\_az) | Enable RDS Multi-AZ standby for the Airbyte config database. Disable in dev for cost; enable in production. | `bool` | `false` | no |
| <a name="input_airbyte_rds_skip_final_snapshot"></a> [airbyte\_rds\_skip\_final\_snapshot](#input\_airbyte\_rds\_skip\_final\_snapshot) | Skip the final RDS snapshot on destroy. Set to true for dev environments; false for production to prevent data loss. | `bool` | `true` | no |
| <a name="input_airbyte_s3_force_destroy"></a> [airbyte\_s3\_force\_destroy](#input\_airbyte\_s3\_force\_destroy) | Allow Terraform to empty and destroy the Airbyte S3 bucket on destroy. Safe in dev; must be false in production. | `bool` | `false` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | Map of S3 buckets to manage | <pre>map(object({<br/>    name               = string<br/>    layer              = string<br/>    transition_ia      = number<br/>    transition_glacier = number<br/>    expiration_days    = number<br/>  }))</pre> | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Company name prefix used in resource names and to look up shared networking resources by tag. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_gdrive_sync_enabled"></a> [gdrive\_sync\_enabled](#input\_gdrive\_sync\_enabled) | Whether to create the EventBridge Scheduler rule that triggers the gdrive sync Lambda. Set to false to deploy the function without scheduling (useful for manual testing). | `bool` | `true` | no |
| <a name="input_gdrive_sync_log_retention_days"></a> [gdrive\_sync\_log\_retention\_days](#input\_gdrive\_sync\_log\_retention\_days) | CloudWatch log retention in days for the gdrive sync Lambda log group. | `number` | `30` | no |
| <a name="input_gdrive_sync_memory"></a> [gdrive\_sync\_memory](#input\_gdrive\_sync\_memory) | Lambda memory in MB for the gdrive sync function. Higher memory also increases CPU and network bandwidth. | `number` | `512` | no |
| <a name="input_gdrive_sync_schedule"></a> [gdrive\_sync\_schedule](#input\_gdrive\_sync\_schedule) | EventBridge Scheduler cron expression for the gdrive sync Lambda. Default is daily at 02:00 UTC. | `string` | `"cron(0 2 * * ? *)"` | no |
| <a name="input_gdrive_sync_timeout"></a> [gdrive\_sync\_timeout](#input\_gdrive\_sync\_timeout) | Lambda timeout in seconds for the gdrive sync function. Max 900 (15 min). Increase if the TEA folder has many large files. | `number` | `900` | no |
| <a name="input_gdrive_tea_folder_id"></a> [gdrive\_tea\_folder\_id](#input\_gdrive\_tea\_folder\_id) | Google Drive folder ID for the TEA source folder. Found in the Drive URL: drive.google.com/drive/folders/<FOLDER\_ID>. | `string` | n/a | yes |
| <a name="input_glue_crawlers"></a> [glue\_crawlers](#input\_glue\_crawlers) | Map of Glue crawlers to provision. Each entry creates a crawler with its own IAM role, KMS key, and security configuration. Set enabled=false to suspend the schedule without destroying the crawler. | <pre>map(object({<br/>    s3_bucket_key = string<br/>    s3_prefix     = string<br/>    database_key  = string<br/>    table_prefix  = string<br/>    schedule      = string<br/>    enabled       = bool<br/>  }))</pre> | `{}` | no |
| <a name="input_glue_databases"></a> [glue\_databases](#input\_glue\_databases) | Map of Glue catalog databases to manage | <pre>map(object({<br/>    name        = string<br/>    description = string<br/>  }))</pre> | n/a | yes |
| <a name="input_lakeformation_admin_arns"></a> [lakeformation\_admin\_arns](#input\_lakeformation\_admin\_arns) | Additional IAM principal ARNs (roles or users) to grant Lake Formation admin rights beyond the Terraform execution role. Useful for granting data platform team members LF admin access. | `list(string)` | `[]` | no |
| <a name="input_lakeformation_de_database_permissions"></a> [lakeformation\_de\_database\_permissions](#input\_lakeformation\_de\_database\_permissions) | Lake Formation database-level permissions granted to the Data Engineer role on bronze and silver. Defaults to DESCRIBE only. Add DROP in dev to allow cleanup of test databases — remove before replicating to stg/prod. | `list(string)` | <pre>[<br/>  "DESCRIBE"<br/>]</pre> | no |
| <a name="input_lakeformation_de_role_arns"></a> [lakeformation\_de\_role\_arns](#input\_lakeformation\_de\_role\_arns) | ARNs of Data Engineer SSO roles to grant Lake Formation data permissions on bronze and silver databases. Permissions at the table level are controlled by lakeformation\_de\_table\_permissions. | `list(string)` | `[]` | no |
| <a name="input_lakeformation_de_table_permissions"></a> [lakeformation\_de\_table\_permissions](#input\_lakeformation\_de\_table\_permissions) | Lake Formation table-level permissions granted to the Data Engineer role on bronze and silver. Defaults to read-only. Add DROP in dev to allow cleanup of test tables — remove before replicating to stg/prod. | `list(string)` | <pre>[<br/>  "SELECT",<br/>  "DESCRIBE"<br/>]</pre> | no |
| <a name="input_lakeformation_terraform_role_name"></a> [lakeformation\_terraform\_role\_name](#input\_lakeformation\_terraform\_role\_name) | Name of the IAM role used by Terraform to manage this stack. Registered as a Lake Formation admin so Terraform retains the ability to manage LF resources after location registration. | `string` | `"region-20-terraform-execution-role"` | no |
| <a name="input_oci_bastion_host"></a> [oci\_bastion\_host](#input\_oci\_bastion\_host) | OCI bastion host to forward traffic to the Oracle DB | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources required | `map(string)` | `{}` | no |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |
| <a name="input_vpn_available"></a> [vpn\_available](#input\_vpn\_available) | Whether the Client VPN endpoint and its security group are deployed in this environment. When false, no direct ingress rules are added to the Airbyte instance SG from the VPN. Set to false in environments where the VPN has not yet been provisioned. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_airbyte_asg_name"></a> [airbyte\_asg\_name](#output\_airbyte\_asg\_name) | Auto Scaling Group name for the Airbyte EC2 instance. |
| <a name="output_airbyte_iam_user_arn"></a> [airbyte\_iam\_user\_arn](#output\_airbyte\_iam\_user\_arn) | ARN of the Airbyte Cloud IAM user |
| <a name="output_airbyte_instance_sg_id"></a> [airbyte\_instance\_sg\_id](#output\_airbyte\_instance\_sg\_id) | Instance security group ID for the Airbyte EC2 instance. Use this to allow ingress from other resources. |
| <a name="output_airbyte_rds_endpoint"></a> [airbyte\_rds\_endpoint](#output\_airbyte\_rds\_endpoint) | RDS PostgreSQL endpoint for the Airbyte config database. |
| <a name="output_airbyte_rds_secret_arn"></a> [airbyte\_rds\_secret\_arn](#output\_airbyte\_rds\_secret\_arn) | ARN of the Secrets Manager secret holding Airbyte RDS credentials. |
| <a name="output_airbyte_s3_bucket_name"></a> [airbyte\_s3\_bucket\_name](#output\_airbyte\_s3\_bucket\_name) | S3 bucket name used by Airbyte for logs and artifacts. |
| <a name="output_airbyte_secret_arn"></a> [airbyte\_secret\_arn](#output\_airbyte\_secret\_arn) | ARN of the Secrets Manager secret storing Airbyte credentials |
| <a name="output_aws_caller_identity"></a> [aws\_caller\_identity](#output\_aws\_caller\_identity) | AWS caller identity information, or null when the stack is disabled (create = false) |
| <a name="output_bucket_arns"></a> [bucket\_arns](#output\_bucket\_arns) | All S3 bucket ARNs |
| <a name="output_bucket_names"></a> [bucket\_names](#output\_bucket\_names) | All S3 bucket names |
| <a name="output_glue_database_names"></a> [glue\_database\_names](#output\_glue\_database\_names) | Glue catalog database names |
| <a name="output_lakeformation_bronze_location_arn"></a> [lakeformation\_bronze\_location\_arn](#output\_lakeformation\_bronze\_location\_arn) | ARN of the S3 bronze bucket registered as a Lake Formation data lake location |
| <a name="output_lakeformation_silver_location_arn"></a> [lakeformation\_silver\_location\_arn](#output\_lakeformation\_silver\_location\_arn) | ARN of the S3 silver bucket registered as a Lake Formation data lake location |
| <a name="output_user_data_script"></a> [user\_data\_script](#output\_user\_data\_script) | Rendered user-data bootstrap script as it will be passed to the EC2 instance. Use 'terraform output -raw user\_data\_script' to inspect it before ap  plying. |
<!-- END_TF_DOCS -->
