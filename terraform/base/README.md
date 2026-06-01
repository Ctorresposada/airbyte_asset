# Terraform Base Stack

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_github_oidc"></a> [github\_oidc](#module\_github\_oidc) | ../modules/oidc-provider | n/a |
| <a name="module_terraform_state_management"></a> [terraform\_state\_management](#module\_terraform\_state\_management) | ../modules/state-management | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Target deployment region | `string` | n/a | yes |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Name to be appended to all resources as prefix | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Target deployment environment | `string` | n/a | yes |
| <a name="input_team"></a> [team](#input\_team) | Team that manages this project | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
