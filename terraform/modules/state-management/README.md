# Terraform AWS State Initialization

Use this module if you need to standardize the way you create your `S3 Bucket` to be utilized in Terraform's state management.

This will not automate the process, only standardize, meaning:

- You'll have to first manually apply this module as in [examples/main.tf](./examples/main.tf);
- Grab the equivalent of what is commented in [examples/main.tf](./examples/main.tf) from the backend configuration block in the `output` of this module;
- Run `terraform init` again and accept Terraform's prompt to migrate state to S3;
- Move on to the next task!


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.28.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_kms_key"></a> [kms\_key](#module\_kms\_key) | terraform-aws-modules/kms/aws | 1.5.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.10.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy.state_management](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_state_management_iam_policy"></a> [create\_state\_management\_iam\_policy](#input\_create\_state\_management\_iam\_policy) | Whether to create the IAM policy | `bool` | `true` | no |
| <a name="input_kms_enable_default_policy"></a> [kms\_enable\_default\_policy](#input\_kms\_enable\_default\_policy) | Whether to enable the default policy for the KMS key | `bool` | `true` | no |
| <a name="input_kms_key_administrators"></a> [kms\_key\_administrators](#input\_kms\_key\_administrators) | The list of IAM users and roles allowed to administer the KMS key | `list(string)` | `[]` | no |
| <a name="input_kms_key_alias"></a> [kms\_key\_alias](#input\_kms\_key\_alias) | The alias for the KMS key used for Terraform state encryption | `string` | n/a | yes |
| <a name="input_kms_key_users"></a> [kms\_key\_users](#input\_kms\_key\_users) | The list of IAM users and roles allowed to use the KMS key | `list(string)` | `[]` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | The name of the S3 bucket for storing Terraform state | `string` | n/a | yes |
| <a name="input_state_management_iam_policy_description"></a> [state\_management\_iam\_policy\_description](#input\_state\_management\_iam\_policy\_description) | The description of the IAM policy | `string` | `"Terraform State Management policy"` | no |
| <a name="input_state_management_iam_policy_name"></a> [state\_management\_iam\_policy\_name](#input\_state\_management\_iam\_policy\_name) | The name of the IAM policy | `string` | `"TerraformStateManagement"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_config_terraform_block"></a> [backend\_config\_terraform\_block](#output\_backend\_config\_terraform\_block) | Terraform backend configuration block |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | The ID of the S3 bucket |
| <a name="output_state_management_iam_policy_arn"></a> [state\_management\_iam\_policy\_arn](#output\_state\_management\_iam\_policy\_arn) | The ARN of the State Management IAM policy |
<!-- END_TF_DOCS -->
