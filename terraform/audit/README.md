# Terraform Audit Stack

This stack provisions the centralized VPC Flow Logs infrastructure in the audit account: a KMS customer-managed key (CMK) and an encrypted S3 bucket that receives VPC Flow Logs delivered cross-account from the dev and prod accounts. The bucket policy and KMS key policy are scoped to the `delivery.logs.amazonaws.com` service principal with `aws:SourceAccount` conditions, ensuring only the explicitly listed source accounts can deliver logs.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.44.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_flow_log_bucket"></a> [flow\_log\_bucket](#module\_flow\_log\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 4.0 |
| <a name="module_flow_log_kms"></a> [flow\_log\_kms](#module\_flow\_log\_kms) | terraform-aws-modules/kms/aws | ~> 3.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy_document.flow_log_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the audit account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name to be appended to all resources as prefix | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_flow_log_bucket_force_destroy"></a> [flow\_log\_bucket\_force\_destroy](#input\_flow\_log\_bucket\_force\_destroy) | Allow Terraform to destroy the Flow Log S3 bucket even when it contains objects; set true only for non-production environments | `bool` | `false` | no |
| <a name="input_flow_log_bucket_name"></a> [flow\_log\_bucket\_name](#input\_flow\_log\_bucket\_name) | Deterministic name for the centralized VPC Flow Logs S3 bucket in the audit account | `string` | n/a | yes |
| <a name="input_flow_log_glacier_transition_days"></a> [flow\_log\_glacier\_transition\_days](#input\_flow\_log\_glacier\_transition\_days) | Days after object creation before transitioning VPC Flow Log objects to Glacier Instant Retrieval. Must be less than flow\_log\_retention\_days. Glacier IR has a 90-day minimum billing duration. | `number` | `30` | no |
| <a name="input_flow_log_retention_days"></a> [flow\_log\_retention\_days](#input\_flow\_log\_retention\_days) | Number of days to retain VPC Flow Log objects in S3 before expiration; audit logs are typically retained longer than per-env logs | `number` | `365` | no |
| <a name="input_source_account_ids"></a> [source\_account\_ids](#input\_source\_account\_ids) | List of AWS account IDs permitted to deliver VPC Flow Logs to the centralized audit bucket | `list(string)` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_flow_log_bucket_arn"></a> [flow\_log\_bucket\_arn](#output\_flow\_log\_bucket\_arn) | ARN of the centralized S3 bucket receiving VPC Flow Logs from all source accounts. Used as the flow\_log\_bucket\_arn input to the networking stack, or null when the stack is disabled (create = false). |
| <a name="output_flow_log_bucket_id"></a> [flow\_log\_bucket\_id](#output\_flow\_log\_bucket\_id) | Name (ID) of the centralized VPC Flow Logs S3 bucket, or null when the stack is disabled (create = false). |
| <a name="output_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#output\_flow\_log\_kms\_key\_arn) | ARN of the KMS CMK used to encrypt VPC Flow Logs in the centralized bucket, or null when the stack is disabled (create = false). |
<!-- END_TF_DOCS -->
