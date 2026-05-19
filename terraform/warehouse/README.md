# warehouse stack

Redshift data warehouse (used with Spectrum over S3) and its supporting KMS CMKs. Initial scope: Redshift data CMK (R2EP2IC-106).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_redshift_kms"></a> [redshift\_kms](#module\_redshift\_kms) | terraform-aws-modules/kms/aws | ~> 3.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID of the target account; used to construct the cross-account assume\_role ARN | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name to be appended to all resources as prefix | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_redshift_key_users"></a> [redshift\_key\_users](#input\_redshift\_key\_users) | List of IAM principal ARNs (roles / users) permitted to use the Redshift KMS CMK for read/write operations (Encrypt, Decrypt, ReEncrypt*, GenerateDataKey*, DescribeKey). An empty list means no principals other than the account root can use the key — safe default for first apply. | `list(string)` | `[]` | no |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_redshift_kms_alias_arn"></a> [redshift\_kms\_alias\_arn](#output\_redshift\_kms\_alias\_arn) | ARN of the KMS alias for the Redshift CMK, or null when the stack is disabled (create = false). |
| <a name="output_redshift_kms_key_arn"></a> [redshift\_kms\_key\_arn](#output\_redshift\_kms\_key\_arn) | ARN of the KMS CMK used to encrypt Redshift data at rest, or null when the stack is disabled (create = false). |
| <a name="output_redshift_kms_key_id"></a> [redshift\_kms\_key\_id](#output\_redshift\_kms\_key\_id) | Globally unique identifier of the Redshift KMS CMK, or null when the stack is disabled (create = false). |
<!-- END_TF_DOCS -->
