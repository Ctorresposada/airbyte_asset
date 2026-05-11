# GitHub Workflows Documentation

This directory contains references for all GitHub Actions workflows in this repository.

## Workflow Overview

| Workflow | Type | Trigger | Purpose |
|----------|------|---------|---------|
| [build_and_push.yml](build_and_push.md) | Reusable | Called by orchestrators | Build and push Docker images to ECR |
| [terraform_plan.yml](#) | Reusable | Called by orchestrators | Generate and validate Terraform plans |
| [terraform_apply.yml](#) | Reusable | Called by orchestrators | Apply approved Terraform changes |
| [terraform_base.yml](#) | Orchestrator (Infrastructure) | Push / PR | Deploy base infrastructure (no containers) |
| [terraform_pull_request.yaml](terraform_pull_request.md) | Orchestrator | Pull Request | Main PR validation workflow |
| [terraform_checks.yaml](terraform_checks.md) | Reusable | Called by other workflows | Terraform validation and security |
| [general_checks.yaml](general_checks.md) | Reusable | Called by other workflows | Code quality and secret detection |

## Guides and Documentation

| Guide | Description |
|-------|-------------|
| [Deployment with Artifacts](deployment_with_artifacts.md) | **Complete deployment guide** covering both container-based and infrastructure-only stacks |
| [Build and Push Setup](build_and_push.md) | Setting up Docker image builds and ECR publishing |

### Two Types of Orchestrator Workflows

This repository uses two patterns for deploying infrastructure:

**1. Container-Based Orchestrators**
- **Use for:** Lambda functions, ECS services, or any infrastructure using Docker images
- **Flow:** `Build → Test → Scan → Terraform Plan → Push to ECR → Terraform Apply`
- **Features:** Includes build/test/security phases, dynamically passes image versions to Terraform
- **Guide:** [Creating Container-Based Stacks](deployment_with_artifacts.md#creating-new-container-based-stacks)

**2. Infrastructure-Only Orchestrators** (e.g., [terraform_base.yml](../workflows/terraform_base.yml))
- **Use for:** VPCs, databases, IAM roles, S3 buckets, ECR repositories, and other pure infrastructure
- **Flow:** `Terraform Plan → Terraform Apply`
- **Features:** No build phase, simpler and faster execution
- **Guide:** [Creating Infrastructure-Only Stacks](deployment_with_artifacts.md#creating-new-infrastructure-only-stacks)

## Workflow Architecture

### Pull Request Flow

```
Pull Request Created
         │
         ├─────────────────────────────────┐
         │                                 │
    Terraform Checks               General Checks
         │                                 │
         ├─ terraform fmt                  ├─ yamllint
         ├─ terraform validate             └─ gitleaks
         ├─ tflint
         └─ checkov
         │                                 │
         └─────────────────────────────────┘
                        │
                 All Checks Pass
                        │
                  Ready to Merge
```

### Deployment Flow for Container-Based Stacks

For stacks that depend on Docker containers:

```
Pull Request
         │
    Build & Test
         │
    ├─ Python/dependencies
    ├─ Linting & tests
    └─ Security scans
         │
    Build Docker Image
         │
    ├─ Multi-arch build
    ├─ Trivy scan
    └─ Generate version
         │
    Push to ECR (PR Phase)
         │
    ├─ Multi-platform
    ├─ Tag: sha-<commit>
    └─ OIDC auth
         │
    Terraform Plan
         │
    ├─ Use image version
    ├─ Checkov security
    └─ Upload artifact
         │
    Review & Merge
         │
    Terraform Apply
         │
    ├─ Download plan
    ├─ Apply changes
    └─ Deploy to AWS
         (using image already in ECR)
```

**Note:** The `build_and_push` workflow now runs only during PR events, pushing images to ECR before Terraform planning to ensure the plan references an existing image.

### Deployment Flow for Infrastructure-Only Stacks

For pure infrastructure:

```
Pull Request
         │
    Terraform Plan
         │
    ├─ terraform init
    ├─ terraform validate
    ├─ Checkov security
    └─ Upload artifact
         │
    Review & Merge
         │
    Terraform Apply
         │
    ├─ Download plan
    ├─ Apply changes
    └─ Deploy to AWS
```

See the [**Deployment with Artifacts Guide**](deployment_with_artifacts.md) for the complete process, including:
- Two orchestrator workflow types (container-based and infrastructure-only)
- Detailed workflow orchestration patterns
- Image version management for container stacks
- Common deployment scenarios
- Troubleshooting guide
- Step-by-step guides for creating new stacks

## Additional Resources

### GitHub Actions

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Action Marketplace](https://github.com/marketplace?type=actions)
- [GitHub Actions Community](https://github.community/c/code-to-cloud/github-actions/41)

### Tools Documentation

- [Terraform](https://developer.hashicorp.com/terraform/docs)
- [TFLint](https://github.com/terraform-linters/tflint)
- [Checkov](https://www.checkov.io/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Trivy](https://aquasecurity.github.io/trivy/)
- [yamllint](https://yamllint.readthedocs.io/)

### AWS

- [AWS OIDC Setup](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
