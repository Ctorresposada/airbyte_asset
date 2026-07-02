# Module: airbyte-ec2

Self-hosted Airbyte on an EC2 Auto Scaling Group using [abctl](https://github.com/airbytehq/abctl) (kind-in-Docker). All durable state is externalized to RDS, S3, and Secrets Manager. The kind cluster holds no persistent data — ASG replacement rebuilds it from scratch.

**Approximate cost:** ~$150/mo (m6a.2xlarge + db.t3.micro + S3/KMS/Secrets)

**When to use:** Simple, low-overhead deployments where Kubernetes operational overhead is not desired.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.12 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.12 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.cloudwatch_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rds_enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.airbyte](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.airbyte_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.airbyte_values](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.instance_all_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.instance_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rds_from_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_password.rds](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.kms_propagation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.airbyte_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.rds_monitoring_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_ssl_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | S3 bucket name for ALB access logs. When non-empty, ALB access logging is enabled. The bucket must already exist with the correct ELB service principal policy. | `string` | `""` | no |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | S3 key prefix for ALB access logs. Only used when alb\_access\_logs\_bucket is set. | `string` | `""` | no |
| <a name="input_alb_certificate_arn"></a> [alb\_certificate\_arn](#input\_alb\_certificate\_arn) | ACM certificate ARN for the ALB HTTPS listener. If empty and domain\_name is set, the module creates and validates an ACM certificate automatically. | `string` | `""` | no |
| <a name="input_alb_deletion_protection"></a> [alb\_deletion\_protection](#input\_alb\_deletion\_protection) | Enable deletion protection on the ALB. Recommended for production. Must be disabled before the ALB can be destroyed. | `bool` | `false` | no |
| <a name="input_alb_internal"></a> [alb\_internal](#input\_alb\_internal) | Whether the Application Load Balancer is internal (true) or internet-facing (false). Set to false to expose Airbyte publicly via an internet-facing ALB. | `bool` | `false` | no |
| <a name="input_alb_subnet_ids"></a> [alb\_subnet\_ids](#input\_alb\_subnet\_ids) | List of subnet IDs for the Application Load Balancer. Use public subnets when alb\_internal = false; private subnets otherwise. Required when create\_alb = true. | `list(string)` | `[]` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | CIDR blocks permitted to reach the ALB on port 443 (and port 80 for HTTPS redirect). Defaults to 0.0.0.0/0 for internet-facing ALBs. Restrict for internal deployments. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | ID of the Docker-enabled AMI used for the Airbyte EC2 instance. Amazon Linux 2023 is recommended; Docker will be installed via user-data if not pre-baked. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | When false, no resources are created. Set to false in a tfvars file to soft-delete everything this module manages while preserving Terraform state. | `bool` | `true` | no |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Whether to create an Application Load Balancer for the Airbyte webapp. When true, also creates an ACM certificate and Route53 record if domain\_name and route53\_zone\_id are provided. | `bool` | `true` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Fully qualified domain name for the Airbyte console (e.g. 'airbyte.example.com'). Used for the Route53 A record and ACM certificate. Required when create\_alb = true. | `string` | `""` | no |
| <a name="input_ebs_volume_size"></a> [ebs\_volume\_size](#input\_ebs\_volume\_size) | Size (in GB) of the root EBS volume for the Airbyte EC2 instance. 50 GB is the minimum; increase for high-volume syncs. | `number` | `50` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for the Airbyte ASG. m6a.2xlarge (8 vCPU, 32 GB) is the recommended minimum. Replication jobs request ~9 CPU per sync; xlarge (4 vCPU) cannot run even a single sync. | `string` | `"m6a.2xlarge"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain CloudWatch log events for the Airbyte log group. Defaults to 365 to satisfy CKV\_AWS\_338; override to a shorter period for dev/staging. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix applied to every resource created by this module (e.g. 'acme-airbyte-dev'). | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for the Auto Scaling Group instances and the RDS DB subnet group. | `list(string)` | n/a | yes |
| <a name="input_rds_backup_retention_days"></a> [rds\_backup\_retention\_days](#input\_rds\_backup\_retention\_days) | Number of days to retain automated RDS backups. Set to 0 to disable backups (not recommended). | `number` | `7` | no |
| <a name="input_rds_db_name"></a> [rds\_db\_name](#input\_rds\_db\_name) | Name of the PostgreSQL database used by Airbyte for configuration storage. | `string` | `"airbyte"` | no |
| <a name="input_rds_deletion_protection"></a> [rds\_deletion\_protection](#input\_rds\_deletion\_protection) | Enable RDS deletion protection. Recommended for production. Must be disabled before destroy. | `bool` | `false` | no |
| <a name="input_rds_instance_class"></a> [rds\_instance\_class](#input\_rds\_instance\_class) | RDS instance class for the Airbyte PostgreSQL config database. db.t3.micro is sufficient at small scale. Use db.t3.small or larger for production with many connectors and high sync frequency. | `string` | `"db.t3.micro"` | no |
| <a name="input_rds_multi_az"></a> [rds\_multi\_az](#input\_rds\_multi\_az) | Enable Multi-AZ for the RDS instance. Doubles cost but provides automatic failover. Recommended for production. | `bool` | `false` | no |
| <a name="input_rds_skip_final_snapshot"></a> [rds\_skip\_final\_snapshot](#input\_rds\_skip\_final\_snapshot) | Skip the final RDS snapshot on destroy. Set to false for production environments to prevent accidental data loss. | `bool` | `true` | no |
| <a name="input_rds_temporal_db_name"></a> [rds\_temporal\_db\_name](#input\_rds\_temporal\_db\_name) | Name of the PostgreSQL database used by Temporal (workflow engine). Resides on the same RDS instance as rds\_db\_name. | `string` | `"temporal"` | no |
| <a name="input_rds_username"></a> [rds\_username](#input\_rds\_username) | PostgreSQL username for the Airbyte application user. | `string` | `"airbyte"` | no |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID for creating the Airbyte DNS record and ACM certificate validation. Required when create\_alb = true. | `string` | `""` | no |
| <a name="input_s3_force_destroy"></a> [s3\_force\_destroy](#input\_s3\_force\_destroy) | Allow Terraform to destroy the Airbyte S3 bucket even when it contains objects. Set to true only for dev/staging where data loss on destroy is acceptable. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of additional tags to apply to all resources created by this module. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC into which Airbyte resources are deployed. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_airbyte_admin_secret_arn"></a> [airbyte\_admin\_secret\_arn](#output\_airbyte\_admin\_secret\_arn) | ARN of the Secrets Manager secret containing the Airbyte web UI admin credentials. Populated at instance boot by user-data. |
| <a name="output_airbyte_url"></a> [airbyte\_url](#output\_airbyte\_url) | HTTPS URL for the Airbyte web console. Null when domain\_name is not set. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | ALB DNS name. Null when create\_alb = false. |
| <a name="output_alb_sg_id"></a> [alb\_sg\_id](#output\_alb\_sg\_id) | ID of the security group attached to the ALB. Null when create\_alb = false. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Canonical hosted zone ID of the ALB. Used by Route53 alias records. Null when create\_alb = false. |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of the Auto Scaling Group managing the Airbyte EC2 instance. |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the ACM certificate used by the ALB. Null when create\_alb = false or no certificate is configured. |
| <a name="output_instance_role_arn"></a> [instance\_role\_arn](#output\_instance\_role\_arn) | ARN of the IAM role attached to the Airbyte EC2 instance profile. Grant this role additional permissions if needed. |
| <a name="output_instance_role_name"></a> [instance\_role\_name](#output\_instance\_role\_name) | Name of the IAM role attached to the Airbyte EC2 instance profile. Use this to attach additional policies. |
| <a name="output_instance_sg_id"></a> [instance\_sg\_id](#output\_instance\_sg\_id) | ID of the security group attached to the Airbyte EC2 instance. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used to encrypt all Airbyte resources. |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | ID of the KMS key used to encrypt all Airbyte resources. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | Name of the CloudWatch log group for Airbyte system and pod logs. |
| <a name="output_rds_endpoint"></a> [rds\_endpoint](#output\_rds\_endpoint) | RDS PostgreSQL endpoint in host:port format. Null when create = false. |
| <a name="output_rds_instance_id"></a> [rds\_instance\_id](#output\_rds\_instance\_id) | RDS instance identifier for the Airbyte config database. |
| <a name="output_rds_secret_arn"></a> [rds\_secret\_arn](#output\_rds\_secret\_arn) | ARN of the Secrets Manager secret containing RDS credentials (username, password, host, port, dbname). |
| <a name="output_rds_sg_id"></a> [rds\_sg\_id](#output\_rds\_sg\_id) | Security group ID of the RDS instance. Null when create = false. |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket used by Airbyte for logs and artifacts. |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket used by Airbyte for logs and artifacts. |
| <a name="output_ssm_parameter_name"></a> [ssm\_parameter\_name](#output\_ssm\_parameter\_name) | Name of the SSM SecureString parameter that holds the rendered Airbyte Helm values YAML. |
| <a name="output_user_data_script"></a> [user\_data\_script](#output\_user\_data\_script) | Rendered user-data bootstrap script. Use 'terraform output -raw user\_data\_script' to inspect before applying. |
<!-- END_TF_DOCS -->
