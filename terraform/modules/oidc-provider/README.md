# Terraform AWS OIDC Provider for GitHub Actions

This Terraform module creates an AWS IAM OIDC identity provider that enables GitHub Actions to authenticate with AWS without using long-lived credentials. This is a secure way to grant GitHub Actions workflows access to AWS resources.

## Features

- Creates an AWS IAM OIDC provider for GitHub Actions
- Creates an IAM role that can be assumed by GitHub Actions workflows
- Supports restricting access to specific GitHub repositories or organizations
- Supports attaching AWS managed policies, custom policies, or inline policies
- Configurable session duration
- Tags support for resource management

## Usage

### Basic Example - Single Repository

```hcl
module "github_oidc" {
  source = "../terraform-aws-oidc-provider"

  role_name = "github-actions-role"
  github_repositories = [
    "myorg/myrepo"
  ]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Multiple Repositories

```hcl
module "github_oidc" {
  source = "../terraform-aws-oidc-provider"

  role_name = "github-actions-deployment-role"
  github_repositories = [
    "myorg/frontend-app",
    "myorg/backend-api",
    "myorg/infrastructure"
  ]

  attach_custom_policy = true
  custom_policy_arn    = aws_iam_policy.deployment_policy.arn

  max_session_duration = 7200  # 2 hours

  tags = {
    Team        = "platform"
    Environment = "production"
  }
}
```

### Organization-Wide Access

```hcl
module "github_oidc_org" {
  source = "../terraform-aws-oidc-provider"

  role_name           = "github-actions-org-role"
  github_organization = "myorg"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]

  tags = {
    Scope = "organization-wide"
  }
}
```

### With Inline Policy

```hcl
module "github_oidc_ecr" {
  source = "../terraform-aws-oidc-provider"

  role_name = "github-actions-ecr-push"
  github_repositories = [
    "myorg/container-app"
  ]

  attach_inline_policy = true
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "ECR image push"
  }
}
```

## GitHub Actions Workflow Configuration

After deploying this module, use the output `github_actions_config` or configure your workflow like this:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}  # Use the iam_role_arn output
          aws-region: us-east-1
          role-session-name: GitHubActions-${{ github.run_id }}

      - name: Verify AWS identity
        run: aws sts get-caller-identity
```

## Important Notes

- **GitHub Repositories vs Organization**: You must specify either `github_repositories` (list of specific repos) OR `github_organization` (all repos in an org), but not both.
- **Thumbprints**: The default thumbprint list is current as of 2024. GitHub rarely changes these, but you may need to update them in the future.
- **Session Duration**: The default session duration is 1 hour (3600 seconds). Adjust based on your workflow needs (max 12 hours).
- **Permissions**: Ensure your GitHub Actions workflow includes `id-token: write` permission for OIDC to work.

## Security Best Practices

1. **Principle of Least Privilege**: Only grant the minimum permissions required for your workflows
2. **Use Repository-Specific Access**: Prefer `github_repositories` over `github_organization` when possible
3. **Monitor IAM Role Usage**: Enable CloudTrail to track when and how the role is used
4. **Rotate Thumbprints**: Check GitHub's documentation periodically for thumbprint updates
5. **Use Environment Protection Rules**: Combine with GitHub environment protection rules for additional security

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.github_actions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.github_actions_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.github_actions_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.github_actions_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.github_actions_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attach_custom_policy"></a> [attach\_custom\_policy](#input\_attach\_custom\_policy) | Whether to attach a custom IAM policy to the role | `bool` | `false` | no |
| <a name="input_attach_inline_policy"></a> [attach\_inline\_policy](#input\_attach\_inline\_policy) | Whether to attach an inline policy to the role | `bool` | `false` | no |
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Whether to create the OIDC provider for GitHub Actions | `bool` | `true` | no |
| <a name="input_custom_policy_arn"></a> [custom\_policy\_arn](#input\_custom\_policy\_arn) | ARN of a custom IAM policy to attach to the role | `string` | `null` | no |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | GitHub organization allowed to assume the role (all repos in the org). Cannot be used with github\_repositories. | `string` | `null` | no |
| <a name="input_github_repositories"></a> [github\_repositories](#input\_github\_repositories) | List of GitHub repositories (format: 'owner/repo') allowed to assume the role. Cannot be used with github\_organization. | `list(string)` | `[]` | no |
| <a name="input_inline_policy_json"></a> [inline\_policy\_json](#input\_inline\_policy\_json) | JSON-formatted inline policy to attach to the role | `string` | `null` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | List of AWS managed policy ARNs to attach to the role | `list(string)` | `[]` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration (in seconds) for the IAM role | `number` | `3600` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of an existing OIDC provider to use instead of creating a new one | `string` | `null` | no |
| <a name="input_role_description"></a> [role\_description](#input\_role\_description) | The description of the IAM role | `string` | `"IAM role for GitHub Actions OIDC authentication"` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | The name of the IAM role to be created for GitHub Actions | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | `{}` | no |
| <a name="input_thumbprint_list"></a> [thumbprint\_list](#input\_thumbprint\_list) | List of server certificate thumbprints for GitHub OIDC provider | `list(string)` | <pre>[<br/>  "6938fd4d98bab03faadb97b34396831e3780aea1",<br/>  "1c58a3a8518e8759bf075b76b750d4f2df264fcd"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_actions_config"></a> [github\_actions\_config](#output\_github\_actions\_config) | GitHub Actions workflow configuration snippet |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role for GitHub Actions |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the IAM role for GitHub Actions |
| <a name="output_iam_role_unique_id"></a> [iam\_role\_unique\_id](#output\_iam\_role\_unique\_id) | Unique ID of the IAM role |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the GitHub OIDC provider |
| <a name="output_oidc_provider_url"></a> [oidc\_provider\_url](#output\_oidc\_provider\_url) | URL of the GitHub OIDC provider |
<!-- END_TF_DOCS -->

## References

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Provider Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
