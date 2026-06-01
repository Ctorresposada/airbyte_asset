# Terraform Security Stack

This stack manages the IAM Identity Center (IDC) configuration for the `Data-Lake-Caylent` workforce group as Infrastructure-as-Code. It owns the Identity Store group itself, the `DataEngineer_Prod` and `DataEngineer_Dev` permission sets (their AWS-managed policy attachments and dev inline policy), and the per-account assignments that grant the group access to the dev (`784590287037`) and prod (`029750300494`) accounts.

The IDC instance is owned by the management account (`992382717104`); the stack itself runs in the security account (`510473518105`), which is registered as the IAM Identity Center delegated administrator. All `sso-admin` and `identitystore` API calls are issued from the security account against the global IDC instance ARN.

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

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_identitystore_group.data_lake_caylent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/identitystore_group) | resource |
| [aws_ssoadmin_account_assignment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_managed_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_managed_policy_attachment) | resource |
| [aws_ssoadmin_permission_set.data_engineer_dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set.data_engineer_prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set_inline_policy.data_engineer_dev](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set_inline_policy) | resource |
| [aws_ssoadmin_permission_set_inline_policy.data_engineer_prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set_inline_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID where the stack runs. For the security stack this is the IAM Identity Center delegated administrator account, not the IDC owner (management) account. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region. IAM Identity Center is region-pinned to the IDC home region; this should match it. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code. | `bool` | `true` | no |
| <a name="input_data_engineer_account_assignments"></a> [data\_engineer\_account\_assignments](#input\_data\_engineer\_account\_assignments) | Account assignments granting the Data-Lake-Caylent group access to target accounts. The map key ("prod" or "dev") must match the corresponding permission set resource key. | <pre>map(object({<br/>    aws_account_id = string<br/>  }))</pre> | n/a | yes |
| <a name="input_data_engineer_dev_permission_set"></a> [data\_engineer\_dev\_permission\_set](#input\_data\_engineer\_dev\_permission\_set) | Configuration attributes of the DataEngineer\_Dev permission set in IAM Identity Center. | <pre>object({<br/>    name             = string<br/>    description      = string<br/>    session_duration = string<br/>    managed_policies = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_data_engineer_prod_permission_set"></a> [data\_engineer\_prod\_permission\_set](#input\_data\_engineer\_prod\_permission\_set) | Configuration attributes of the DataEngineer\_Prod permission set in IAM Identity Center. | <pre>object({<br/>    name             = string<br/>    description      = string<br/>    session_duration = string<br/>    managed_policies = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_data_lake_group"></a> [data\_lake\_group](#input\_data\_lake\_group) | Identity Store group representing Caylent members working on the Data Lake. group\_id is required for the import; display\_name and description must match the live values exactly to avoid drift. | <pre>object({<br/>    group_id     = string<br/>    display_name = string<br/>    description  = string<br/>  })</pre> | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_identity_store_id"></a> [identity\_store\_id](#input\_identity\_store\_id) | Identifier of the Identity Store (e.g. d-xxxxxxxxxx) backing the IAM Identity Center instance. | `string` | n/a | yes |
| <a name="input_instance_arn"></a> [instance\_arn](#input\_instance\_arn) | ARN of the IAM Identity Center (SSO) instance under which permission sets and account assignments are managed. | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_assignments"></a> [account\_assignments](#output\_account\_assignments) | Map of account-assignment keys to their target account IDs and permission set ARNs. Empty when the stack is disabled (create = false). |
| <a name="output_data_engineer_dev_permission_set_arn"></a> [data\_engineer\_dev\_permission\_set\_arn](#output\_data\_engineer\_dev\_permission\_set\_arn) | ARN of the DataEngineer\_Dev permission set, or null when the stack is disabled (create = false). |
| <a name="output_data_engineer_prod_permission_set_arn"></a> [data\_engineer\_prod\_permission\_set\_arn](#output\_data\_engineer\_prod\_permission\_set\_arn) | ARN of the DataEngineer\_Prod permission set, or null when the stack is disabled (create = false). |
| <a name="output_data_lake_caylent_group_arn"></a> [data\_lake\_caylent\_group\_arn](#output\_data\_lake\_caylent\_group\_arn) | ARN of the Data-Lake-Caylent Identity Store group, or null when the stack is disabled (create = false). |
| <a name="output_data_lake_caylent_group_id"></a> [data\_lake\_caylent\_group\_id](#output\_data\_lake\_caylent\_group\_id) | Group ID of the Data-Lake-Caylent Identity Store group, or null when the stack is disabled (create = false). |
<!-- END_TF_DOCS -->
