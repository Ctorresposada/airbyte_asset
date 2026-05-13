# Terraform Checks and Tests Workflow

## Overview

This is a **reusable workflow** that performs comprehensive Terraform code quality and security checks without requiring AWS credentials. It validates Terraform syntax, runs linting, and performs security scanning.

**Workflow File:** [.github/workflows/terraform_checks.yaml](../workflows/terraform_checks.yaml)

### Called By
- [terraform_pull_request.yaml](../workflows/terraform_pull_request.yaml) - Runs on pull requests

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `aws_region` | string | `"us-east-1"` | AWS region for Terraform code validation |
| `path` | string | `"."` | Relative path to Terraform code to check |
| `tf_version` | string | `"1.11.3"` | Terraform version to use |

## Required Permissions

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | write | Access and modify repository content |
| `pull-requests` | write | Comment on pull requests with results |
| `id-token` | write | For potential OIDC usage |

## Jobs

### Job 1: Terraform Lint

Validates Terraform code formatting, syntax, and best practices.

#### Steps:

1. **Checkout source code**
   - Uses: `actions/checkout@v4`
   - Fetches repository code

2. **Setup Terraform**
   - Uses: `hashicorp/setup-terraform@v3`
   - Installs Terraform version specified in `tf_version` input
   - Default: v1.11.3

3. **Configure Private Modules Credentials**
   - Uses: `philips-labs/terraform-private-modules-action@v1`
   - Configures Git credentials for private Terraform modules
   - Organization: `${{ github.repository_owner }}`
   - Token: `AUTO_SHIPIT` secret
   - Enables access to private GitHub Terraform modules

4. **Terraform Format Check**
   - Command: `terraform fmt -check -recursive {path}`
   - Validates code follows standard Terraform formatting
   - Checks indentation, spacing, and style
   - Fails if code needs formatting

5. **Terraform Validate**
   - Initializes Terraform: `terraform init -upgrade -input=false -lock=false -reconfigure -backend=false`
   - Runs validation: `terraform validate -no-color`
   - Checks syntax and configuration
   - Validates resource configurations
   - **Note:** Runs without backend configuration (no state file needed)

6. **Verify TFLint config file**
   - Checks if `.config/.tflint.hcl` exists locally
   - If not found, clones from central repository
   - Uses sparse checkout for efficiency
   - Repository: `caylent/terraform-ci`

7. **Setup TFLint**
   - Uses: `terraform-linters/setup-tflint@v4`
   - Version: v0.52.0
   - TFLint is a Terraform linter focused on best practices and AWS-specific rules

8. **Show TFLint version**
   - Command: `tflint --version`
   - Logs version for debugging

9. **Initialize TFLint**
   - Command: `tflint --init --config .config/.tflint.hcl`
   - Downloads TFLint plugins
   - Configures ruleset

10. **Run TFLint**
    - Command: `tflint --config .config/.tflint.hcl --recursive`
    - Scans all Terraform files recursively
    - Applies rules from configuration

### Job 2: Terraform Security Checks

Runs security scanning on Terraform code using Checkov.

#### Steps:

1. **Checkout repo**
   - Uses: `actions/checkout@master`
   - Fetches repository code

2. **Verify Checkov config file**
   - Checks if `.config/.checkov.yml` exists locally
   - If not found, clones from central repository
   - Uses sparse checkout to fetch only config
   - Repository: `caylent/terraform-ci`

3. **Run Checkov action**
   - Uses: `bridgecrewio/checkov-action@master`
   - Scans directory: `.` (entire repository)
   - Config: `.config/.checkov.yml`
   - Generates security scan report

Supports multiple frameworks:
- Terraform
- CloudFormation
- Kubernetes
- Serverless

## Configuration Files

### TFLint Configuration

**Location:** `.config/.tflint.hcl`

### Checkov Configuration

**Location:** `.config/.checkov.yml`

## Best Practices

### Code Organization

```
terraform/
├── modules/
│   ├── vpc/
│   ├── eks/
│   └── rds/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .config/
    ├── .tflint.hcl
    └── .checkov.yml
```

## Related Workflows

- [general_checks.md](general_checks.md) - General code quality checks
- [terraform_pull_request.md](terraform_pull_request.md) - Main PR workflow

## Additional Resources

- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [TFLint Documentation](https://github.com/terraform-linters/tflint)
- [Checkov Documentation](https://www.checkov.io/documentation.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
