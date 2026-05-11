# CI/CD Workflows for Terraform

> **Part of:** [terraform-skill](../SKILL.md)
> **Purpose:** CI/CD integration patterns for Terraform

This document provides detailed CI/CD workflow templates and optimization strategies for infrastructure-as-code pipelines.

---

## Table of Contents

1. [Current Implementation](#current-implementation)
   - [Three-Tier Workflow Architecture](#three-tier-workflow-architecture)
   - [Orchestrator Workflows](#orchestrator-workflows)
   - [Reusable Workflows](#reusable-workflows)
   - [Validation Workflows](#validation-workflows)
   - [Implementation Details](#implementation-details)
2. [Cost Optimization](#cost-optimization)
3. [Automated Cleanup](#automated-cleanup)
4. [Best Practices](#best-practices)

---

## Current Implementation

**Note:** This section documents the actual CI/CD architecture implemented in this repository.

### Three-Tier Workflow Architecture

The repository uses a sophisticated **three-tier architecture** that separates concerns and enables reusability:

```
┌─────────────────────────────────────────────────────────────┐
│               Orchestrator Workflow Layer                   │
│                                                             │
│  • Stack-specific configuration                             │
│  • Coordinates execution order                              │
│  • Passes parameters between workflows                      │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             ▼                            ▼
    ┌────────────────┐           ┌────────────────┐
    │  Build/Push    │           │   Terraform    │
    │   Workflow     │──────────▶│   Workflows    │
    │   (Reusable)   │   Image   │   (Reusable)   │
    │                │  Version  │                │
    └────────────────┘           └────────────────┘
                                         │
                                         ▼
                                ┌────────────────┐
                                │  Validation    │
                                │   Workflows    │
                                │  (terraform_   │
                                │   checks.yaml) │
                                └────────────────┘
```

**Benefits:**
- **Separation of Concerns** - Each layer has a specific responsibility
- **Reusability** - Reusable workflows work for all stacks
- **Consistency** - Same deployment pattern across all infrastructure
- **Maintainability** - Changes to deployment logic only need updates in reusable workflows

### Orchestrator Workflows

**Location:** `.github/workflows/terraform_<stack-name>.yml`

#### Two Orchestrator Types

The repository supports two deployment patterns based on infrastructure requirements:

| Type | Use Case | Flow | Example |
|------|----------|------|---------|
| **Container-Based** | Lambda, ECS, any infrastructure using Docker | `set-env → build-and-push → terraform-plan/apply` | `TBD` |
| **Infrastructure-Only** | VPCs, databases, IAM, S3, pure infrastructure | `set-env → terraform-plan/apply` | `terraform_base.yml` |

#### Container-Based Orchestrator Pattern

```yaml
name: Terraform Data Layer

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/data-layer/**'          # Infrastructure code
      - 'src/data/**'                      # Application code
  push:
    branches: [main]
    paths:
      - 'terraform/data-layer/**'
      - 'src/data/**'

env:
  WORKING_DIR: 'terraform/data-layer'
  ENVIRONMENT: 'dev'
  ECR_REPOSITORY: 'data-layer-app'
  DOCKERFILE_PATH: 'src/data/Dockerfile'

permissions:
  id-token: write       # OIDC authentication
  contents: read
  pull-requests: write
  security-events: write

jobs:
  set-env:
    # Centralizes environment configuration
    outputs:
      AWS_REGION: ${{ steps.credentials.outputs.AWS_REGION }}
      AWS_ROLE_ARN: ${{ steps.credentials.outputs.AWS_ROLE_ARN }}
      WORKING_DIR: ${{ steps.credentials.outputs.WORKING_DIR }}

  build-and-push:
    needs: [set-env]
    uses: ./.github/workflows/build_and_push.yml
    with:
      ecr_repository: ${{ needs.set-env.outputs.ECR_REPOSITORY }}
    outputs:
      image-version: # Used by Terraform

  terraform-plan:
    needs: [set-env, build-and-push]
    if: github.event_name == 'pull_request'
    uses: ./.github/workflows/terraform_plan.yml
    with:
      terraform_vars: '-var image_version=${{ needs.build-and-push.outputs.image-version }}'

  terraform-apply:
    needs: [set-env]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ./.github/workflows/terraform_apply.yml
```

**Key Features:**
- Builds Docker image and passes version to Terraform
- Runs tests, security scans, and vulnerability scanning
- Triggers on both infrastructure AND application code changes
- Coordinates artifact building with infrastructure deployment

#### Infrastructure-Only Orchestrator Pattern

```yaml
name: Terraform Base

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/base/**'               # Only infrastructure
  push:
    branches: [main]
    paths:
      - 'terraform/base/**'

env:
  WORKING_DIR: 'terraform/base'
  ENVIRONMENT: 'dev'

jobs:
  set-env:
    # Environment configuration

  terraform-plan:
    needs: [set-env]
    if: github.event_name == 'pull_request'
    uses: ./.github/workflows/terraform_plan.yml
    # No terraform_vars needed - no dynamic image versions

  terraform-apply:
    needs: [set-env]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ./.github/workflows/terraform_apply.yml
```

**Key Features:**
- No build phase - simpler and faster
- Only triggers on infrastructure code changes
- No dynamic variables for image versions

**Decision Rule:** If your Terraform code references a Docker image tag/version variable that needs to be dynamically set, use container-based. Otherwise, use infrastructure-only.

### Reusable Workflows

**Location:** `.github/workflows/<workflow-name>.yml`

#### 1. build_and_push.yml

**Purpose:** Build Docker images, run tests, scan for vulnerabilities, push to ECR

**Key Features:**
- ✅ OIDC authentication (no long-lived credentials)
- ✅ Multi-architecture builds (linux/amd64, linux/arm64)
- ✅ Python testing with `uv` package manager
- ✅ Security scanning with Trivy and trufflehog
- ✅ Smart tagging strategy

**Workflow:**

```
Pull Request:
  1. Run Tests
     • Set up Python with uv
     • Install dependencies: uv sync
     • Run linting: ruff check
     • Security scan: trufflehog

  2. Build Docker Image
     • Multi-arch setup (QEMU + Buildx)
     • Authenticate to AWS via OIDC
     • Build for linux/amd64 (local load)
     • Generate tags: pr-<number>, sha-<sha>

  3. Security Scanning
     • Run Trivy scan
     • Fail on CRITICAL/HIGH vulnerabilities
     • Upload results to GitHub Security

  4. Output (NO push to ECR)
     • image-version: sha-abc1234
     • Comment on PR with results

Push to Main:
  1. Run Tests (same as PR)

  2. Build Multi-Architecture
     • Build for linux/amd64,linux/arm64
     • Generate tags: main, sha-<sha>, latest

  3. Push to ECR
     • Multi-platform push
     • All tags pushed simultaneously

  4. Output image version for Terraform
```

**Tagging Strategy:**
- `pr-123` - Pull request builds
- `sha-abc1234` - Commit SHA (used by Terraform)
- `main` - Branch name
- `latest` - Only for main branch
- Multi-platform manifest for arm64/amd64

**Configuration:**
```yaml
# In orchestrator workflow
build-and-push:
  uses: ./.github/workflows/build_and_push.yml
  with:
    aws_role_arn: ${{ vars.AWS_ROLE_ARN }}
    aws_region: ${{ vars.AWS_REGION }}
    ecr_repository: 'my-app-repo'
    dockerfile_path: 'src/my-app/Dockerfile'
    trivy_severity: 'CRITICAL,HIGH'  # Optional
    trivy_exit_code: '1'             # Optional
```

#### 2. terraform_plan.yml

**Purpose:** Generate and validate Terraform execution plans

**Workflow:**

```
1. Infrastructure Setup
   • Checkout code
   • Install Terraform v1.11.3
   • Authenticate to AWS via OIDC

2. Terraform Operations
   • Initialize: terraform init -upgrade
   • Select workspace: terraform workspace select <env>
   • Format check: terraform fmt -check -recursive
   • Validate: terraform validate

3. Plan Generation
   • Run: terraform plan -var-file=variables/<env>.tfvars
   • Include dynamic vars if provided (e.g., image version)
   • Generate outputs: tfplan, tfplan.txt, tfplan.json

4. Security Validation
   • Run Checkov on plan
   • Check for security misconfigurations
   • Fail on critical issues

5. Artifact Management
   • Upload plan: tfplan-<stack>-pr-<number>-<sha>
   • Retention: 30 days
   • Post plan output as PR comment
   • Include Checkov results
```

**Configuration:**
```yaml
terraform-plan:
  uses: ./.github/workflows/terraform_plan.yml
  with:
    aws_role_arn: ${{ vars.AWS_ROLE_ARN }}
    aws_region: ${{ vars.AWS_REGION }}
    working_dir: 'terraform/my-stack'
    environment: 'dev'
    terraform_vars: '-var image_version=${{ needs.build-and-push.outputs.image-version }}'
```

#### 3. terraform_apply.yml

**Purpose:** Apply approved Terraform changes safely

**Workflow:**

```
1. PR Artifact Retrieval
   • Find merged PR number (GitHub API)
   • Download pre-approved plan artifact
   • Ensures only reviewed plans are applied

2. Infrastructure Setup
   • Install Terraform v1.11.3
   • Authenticate to AWS via OIDC
   • Initialize and select workspace

3. Apply Changes
   • Execute: terraform apply tfplan
   • Uses exact plan from PR (no surprises)
   • Deploy to AWS

4. Deployment Summary
   • Generate GitHub Actions summary
   • Record applied commit SHA and PR number
```

**Safety Features:**
- Only applies plans that were reviewed in PRs
- Artifact-based approach prevents "drift" between plan and apply
- Requires PR merge (can't apply arbitrary plans)

### Validation Workflows

#### terraform_pull_request.yaml

**Purpose:** Main orchestrator for PR validation

**Triggers:** All pull requests to main branch

**Jobs (run in parallel):**

```
Pull Request Created/Updated
         │
         ├─────────────────┬─────────────────┐
         │                 │                 │
    Terraform          General          Unit Tests
      Checks           Checks          (placeholder)
         │                 │
         ├─ Format         ├─ YAML Lint
         ├─ Validate       └─ Gitleaks
         ├─ TFLint
         └─ Checkov
```

**Configuration:**
```yaml
name: Terraform CI Pull Request

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  terraform_checks:
    uses: ./.github/workflows/terraform_checks.yaml
    with:
      path: "terraform"

  general_checks:
    uses: ./.github/workflows/general_checks.yaml
```

#### terraform_checks.yaml

**Purpose:** Comprehensive Terraform validation and security

**Job 1: Terraform Lint**

1. **Format Check** - `terraform fmt -check -recursive`
2. **Validate** - `terraform validate` (syntax and configuration)
3. **TFLint** - Best practices linting
   - Config: `.config/.tflint.hcl`
   - Version: v0.52.0
   - Recursive scan of all modules

**Job 2: Security Checks**

1. **Checkov** - Security scanning
   - Config: `.config/.checkov.yaml`
   - Scans for misconfigurations
   - Multiple framework support (Terraform, CloudFormation, K8s, Docker)

**Config Management:**
- Checks for local configs first
- Falls back to central repository if not found
- Uses Git sparse checkout for efficiency

#### general_checks.yaml

**Purpose:** General code quality and secret detection

**Job 1: YAML Lint**
- Validates all YAML files
- Config: `.config/.yamllint.yaml`
- Checks syntax, formatting, indentation

**Job 2: Gitleaks**
- Scans entire repository for secrets
- Detects 100+ secret patterns:
  - AWS access keys
  - API tokens
  - Private keys
  - Database credentials
  - OAuth tokens

### Implementation Details

#### Repository Variables

**Location:** Settings → Secrets and variables → Actions → Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_REGION` | AWS deployment region | `us-east-1` |
| `AWS_ROLE_ARN` | OIDC role ARN | `arn:aws:iam::123456789:role/github-actions` |

#### Configuration Files

```
.config/
├── .tflint.hcl       # TFLint rules and plugins
├── .checkov.yaml     # Checkov security policies
└── .yamllint.yaml    # YAML linting rules
```

#### Terraform Module Structure

```
terraform/
├── data-layer/              # Container-based stack
│   ├── main.tf
│   ├── variables.tf
│   │   └── image_version variable
│   ├── locals.tf
│   └── variables/
│       └── dev.tfvars
├── base/                    # Infrastructure-only stack
│   ├── main.tf
│   ├── oidc.tf
│   ├── state.tf
│   └── variables/
│       └── dev.tfvars
└── modules/                 # Reusable modules
    ├── lambda/
    ├── ecs/
    ├── oidc-provider/
    └── state-management/
```

#### Complete Deployment Flow

**Container-Based Stack (Pull Request):**

```
1. Create PR
   ↓
2. build-and-push (PR context)
   • Run tests (linting, unit tests, security)
   • Build Docker image (local load, no push)
   • Scan with Trivy
   • Output: image-version=pr-42
   ↓
3. terraform-plan
   • Init and validate
   • Plan with: -var image_version=pr-42
   • Checkov security scan
   • Upload artifact: tfplan-stack-pr-42-abc1234
   • Comment on PR
   ↓
4. Review and Merge
   ↓
5. Push to Main
   ↓
6. build-and-push (main context)
   • Run tests
   • Build multi-arch image
   • Push to ECR with tags: main, sha-abc1234, latest
   • Output: image-version=sha-abc1234
   ↓
7. terraform-apply
   • Find PR number
   • Download artifact: tfplan-stack-pr-42-abc1234
   • Apply plan
   • Deploy to AWS
```

**Infrastructure-Only Stack:**

```
1. Create PR
   ↓
2. terraform-plan
   • Init and validate
   • Plan with environment tfvars
   • Checkov security scan
   • Upload artifact
   • Comment on PR
   ↓
3. Review and Merge
   ↓
4. Push to Main
   ↓
5. terraform-apply
   • Download artifact
   • Apply plan
   • Deploy to AWS
```

#### Security Features

1. **OIDC Authentication** - No long-lived credentials stored
2. **Artifact-Based Deployment** - Only reviewed plans are applied
3. **Multi-Layer Scanning:**
   - Trivy (container vulnerabilities)
   - Checkov (infrastructure misconfigurations)
   - Gitleaks (secret detection)
   - Trufflehog (secret scanning in application code)
4. **Branch Protection** - Requires PR reviews and status checks
5. **Immutable Tags** - ECR uses immutable tags (can't overwrite)

#### Creating New Stacks

**For Container-Based Stack:**

1. Create Terraform module with `image_version` variable
2. Create application code with Dockerfile
3. Copy orchestrator template
4. Update paths, ECR repository, and variable names

**For Infrastructure-Only Stack:**

1. Create Terraform module (no image variables)
2. Copy infrastructure-only orchestrator template
3. Update paths and configuration

**Documentation:** See `.github/docs/deployment_with_artifacts.md` for complete guides

---

## Cost Optimization

### Strategy

1. **Use mocking for PR validation** (free)
2. **Run integration tests only on main branch** (controlled cost)
3. **Implement auto-cleanup** (prevent orphaned resources)
4. **Tag all test resources** (track spending)

### Example: Conditional Test Execution

```yaml
# GitHub Actions
test:
  runs-on: ubuntu-latest
  steps:
    - name: Run Unit Tests (Mocked)
      run: terraform test

    - name: Run Integration Tests
      if: github.ref == 'refs/heads/main'
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      run: |
        cd tests
        go test -v -timeout 30m
```

### Cost-Aware Test Tags

```go
// In Terratest
terraformOptions := &terraform.Options{
    TerraformDir: "../examples/complete",
    Vars: map[string]interface{}{
        "tags": map[string]string{
            "Environment": "test",
            "TTL":         "2h",
            "CreatedBy":   "CI",
            "JobID":       os.Getenv("GITHUB_RUN_ID"),
        },
    },
}
```

---

## Automated Cleanup

### Cleanup Script (Bash)

```bash
#!/bin/bash
# cleanup-test-resources.sh

# Find and terminate instances older than 2 hours with test tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=test \
  --query 'ResourceTagMappingList[?Tags[?Key==`TTL` && Value<`'$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%S)'`]].ResourceARN' \
  --output text | \
  while read arn; do
    instance_id=$(echo $arn | grep -oP 'instance/\K[^/]+')
    if [ ! -z "$instance_id" ]; then
      echo "Terminating instance: $instance_id"
      aws ec2 terminate-instances --instance-ids $instance_id
    fi
  done
```

### Scheduled Cleanup (GitHub Actions)

```yaml
# .github/workflows/cleanup.yml
name: Cleanup Test Resources

on:
  schedule:
    - cron: '0 */2 * * *'  # Every 2 hours
  workflow_dispatch:        # Manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Run Cleanup Script
        run: ./scripts/cleanup-test-resources.sh
```

---

## Best Practices

### 1. Separate Environments

```yaml
# Different workflows for different environments
.github/workflows/
  terraform-dev.yml
  terraform-staging.yml
  terraform-prod.yml
```

Or use reusable workflows:

```yaml
# .github/workflows/terraform-deploy.yml (reusable)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string

jobs:
  deploy:
    environment: ${{ inputs.environment }}
    # ... deployment steps
```

### 2. Require Approvals for Production

```yaml
apply:
  environment:
    name: production
    # Requires manual approval in GitHub
  when: manual
```

### 3. Use Remote State

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### 4. Implement State Locking

```yaml
# In CI, use -lock-timeout to handle concurrent runs
- name: Terraform Apply
  run: terraform apply -lock-timeout=10m tfplan
```

### 5. Cache Terraform Plugins

```yaml
# GitHub Actions
- name: Cache Terraform Plugins
  uses: actions/cache@v3
  with:
    path: |
      ~/.terraform.d/plugin-cache
    key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
```

### 6. Security Scanning in CI

```yaml
security-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3

    - name: Run Trivy
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: '.'

    - name: Run Checkov
      uses: bridgecrewio/checkov-action@master
      with:
        directory: .
        framework: terraform
```

---

## Troubleshooting

### Issue: Tests fail in CI but pass locally

**Cause:** Different Terraform/provider versions

**Solution:**

```hcl
# versions.tf - Pin versions
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### Issue: Parallel tests conflict

**Cause:** Resource naming collisions

**Solution:**

```go
// Use unique identifiers
uniqueId := random.UniqueId()
bucketName := fmt.Sprintf("test-bucket-%s-%s",
    os.Getenv("GITHUB_RUN_ID"),
    uniqueId)
```

---

## Implementation Documentation References

**Complete documentation for the current implementation can be found in:**

### Main Documentation

- **[.github/docs/README.md](.github/docs/README.md)** - Complete workflow overview and index
- **[.github/docs/deployment_with_artifacts.md](.github/docs/deployment_with_artifacts.md)** - Comprehensive deployment guide
  - Two orchestrator workflow types (container-based and infrastructure-only)
  - Detailed workflow orchestration patterns
  - Image version management for container stacks
  - Common deployment scenarios and troubleshooting
  - Step-by-step guides for creating new stacks

### Workflow Documentation

- **[.github/docs/build_and_push.md](.github/docs/build_and_push.md)** - Docker build, test, and ECR push workflow
- **[.github/docs/terraform_checks.md](.github/docs/terraform_checks.md)** - Terraform validation and security scanning
- **[.github/docs/general_checks.md](.github/docs/general_checks.md)** - Code quality and secret detection
- **[.github/docs/terraform_pull_request.md](.github/docs/terraform_pull_request.md)** - PR validation workflow

### Configuration Files

- **[.config/.tflint.hcl](.config/.tflint.hcl)** - TFLint configuration
- **[.config/.checkov.yaml](.config/.checkov.yaml)** - Checkov security scanning configuration
- **[.config/.yamllint.yaml](.config/.yamllint.yaml)** - YAML linting rules

### Actual Workflow Files

- **[.github/workflows/terraform_base.yml](.github/workflows/terraform_base.yml)** - Infrastructure-only orchestrator example
- **[.github/workflows/build_and_push.yml](.github/workflows/build_and_push.yml)** - Reusable build workflow
- **[.github/workflows/terraform_plan.yml](.github/workflows/terraform_plan.yml)** - Reusable plan workflow
- **[.github/workflows/terraform_apply.yml](.github/workflows/terraform_apply.yml)** - Reusable apply workflow
- **[.github/workflows/terraform_checks.yaml](.github/workflows/terraform_checks.yaml)** - Validation workflow
- **[.github/workflows/general_checks.yaml](.github/workflows/general_checks.yaml)** - Quality checks workflow
- **[.github/workflows/terraform_pull_request.yaml](.github/workflows/terraform_pull_request.yaml)** - PR orchestrator

---

**Back to:** [Main Skill File](../SKILL.md)
