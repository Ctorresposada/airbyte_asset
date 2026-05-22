# warehouse stack

Redshift data warehouse (used with Spectrum over S3) and its supporting KMS CMKs.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.46.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_redshift_kms"></a> [redshift\_kms](#module\_redshift\_kms) | terraform-aws-modules/kms/aws | ~> 3.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_athena_workgroup.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_cloudwatch_log_group.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.redshift_serverless](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.redshift_serverless](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_redshiftserverless_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_namespace) | resource |
| [aws_redshiftserverless_workgroup.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/redshiftserverless_workgroup) | resource |
| [aws_s3_bucket.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.buckets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.redshift](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.redshift_https_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.redshift_s3_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.redshift_sql_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_iam_policy_document.redshift_serverless](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the target account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_athena_results"></a> [athena\_results](#input\_athena\_results) | Configuration for the Athena query results S3 bucket. name sets the bucket name; layer is a tag value; transition\_ia/transition\_glacier are days before moving objects to STANDARD\_IA/GLACIER; expiration\_days is when objects are permanently deleted. | <pre>object({<br/>    name               = string<br/>    layer              = string<br/>    transition_ia      = number<br/>    transition_glacier = number<br/>    expiration_days    = number<br/>  })</pre> | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name to be appended to all resources as prefix | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_data_lake_bucket_arns"></a> [data\_lake\_bucket\_arns](#input\_data\_lake\_bucket\_arns) | List of S3 bucket ARNs the Redshift cluster IAM role can read via Spectrum or COPY (e.g. the gold layer bucket). Empty list means no S3 read policy is attached. Pass full ARNs like "arn:aws:s3:::escr20-gold-dev"; the cluster gets s3:GetObject on <bucket-arn>/* and s3:ListBucket on <bucket-arn>. | `list(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_redshift_admin_username"></a> [redshift\_admin\_username](#input\_redshift\_admin\_username) | Username for the Redshift admin user. The password is managed by Redshift in Secrets Manager (manage\_admin\_password = true), so no password is set in Terraform. | `string` | `"admin"` | no |
| <a name="input_redshift_base_capacity"></a> [redshift\_base\_capacity](#input\_redshift\_base\_capacity) | Base RPU capacity for the workgroup. Minimum allowed by Redshift Serverless is 8. | `number` | `8` | no |
| <a name="input_redshift_db_name"></a> [redshift\_db\_name](#input\_redshift\_db\_name) | Initial database name created inside the Redshift Serverless namespace. Per R2EP2IC-31, Redshift hosts the GOLD layer only. | `string` | `"gold"` | no |
| <a name="input_redshift_key_users"></a> [redshift\_key\_users](#input\_redshift\_key\_users) | List of IAM principal ARNs (roles / users) permitted to use the Redshift KMS CMK for read/write operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey). An empty list means no principals other than the account root can use the key — safe default for first apply. | `list(string)` | `[]` | no |
| <a name="input_redshift_log_retention_days"></a> [redshift\_log\_retention\_days](#input\_redshift\_log\_retention\_days) | Retention in days for the CloudWatch log groups receiving Redshift Serverless userlog / connectionlog / useractivitylog exports. CloudWatch storage cost grows linearly with this value; dev should keep it short. | `number` | `30` | no |
| <a name="input_redshift_max_capacity"></a> [redshift\_max\_capacity](#input\_redshift\_max\_capacity) | Maximum RPU capacity the workgroup can scale to. Acts as a cost ceiling; set lower in dev environments. | `number` | `128` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_athena_results_bucket"></a> [athena\_results\_bucket](#output\_athena\_results\_bucket) | S3 bucket ID for Athena query results, or null when the stack is disabled. |
| <a name="output_athena_workgroup_name"></a> [athena\_workgroup\_name](#output\_athena\_workgroup\_name) | Athena primary workgroup name, or null when the stack is disabled. |
| <a name="output_redshift_admin_secret_arn"></a> [redshift\_admin\_secret\_arn](#output\_redshift\_admin\_secret\_arn) | ARN of the Secrets Manager secret holding the Redshift admin password (Redshift-managed), or null when the stack is disabled. |
| <a name="output_redshift_iam_role_arn"></a> [redshift\_iam\_role\_arn](#output\_redshift\_iam\_role\_arn) | ARN of the IAM role attached to the Redshift Serverless namespace (S3 / Glue read for Spectrum), or null when the stack is disabled. |
| <a name="output_redshift_kms_key_arn"></a> [redshift\_kms\_key\_arn](#output\_redshift\_kms\_key\_arn) | ARN of the KMS CMK used to encrypt Redshift data at rest, or null when the stack is disabled (create = false). |
| <a name="output_redshift_kms_key_id"></a> [redshift\_kms\_key\_id](#output\_redshift\_kms\_key\_id) | Globally unique identifier of the Redshift KMS CMK, or null when the stack is disabled (create = false). |
| <a name="output_redshift_log_group_arns"></a> [redshift\_log\_group\_arns](#output\_redshift\_log\_group\_arns) | ARNs of the CloudWatch log groups receiving Redshift Serverless log exports, or null when the stack is disabled (create = false). |
| <a name="output_redshift_log_group_names"></a> [redshift\_log\_group\_names](#output\_redshift\_log\_group\_names) | Names of the CloudWatch log groups receiving Redshift Serverless log exports, or null when the stack is disabled (create = false). |
| <a name="output_redshift_namespace_arn"></a> [redshift\_namespace\_arn](#output\_redshift\_namespace\_arn) | ARN of the Redshift Serverless namespace, or null when the stack is disabled. |
| <a name="output_redshift_security_group_id"></a> [redshift\_security\_group\_id](#output\_redshift\_security\_group\_id) | Security group ID protecting the Redshift workgroup, or null when the stack is disabled. |
| <a name="output_redshift_workgroup_arn"></a> [redshift\_workgroup\_arn](#output\_redshift\_workgroup\_arn) | ARN of the Redshift Serverless workgroup, or null when the stack is disabled. |
| <a name="output_redshift_workgroup_endpoint"></a> [redshift\_workgroup\_endpoint](#output\_redshift\_workgroup\_endpoint) | Workgroup endpoint object (address + port) used by SQL clients to connect to Redshift, or null when the stack is disabled (create = false). |
<!-- END_TF_DOCS -->
