# Deployment Process for Infrastructure Stacks

This guide explains the complete process for updating and deploying infrastructure stacks. It covers two types of deployments:

1. **Container-Based Stacks** - Infrastructure that depends on Docker images (e.g., Lambda functions, ECS services)
2. **Infrastructure-Only Stacks** - Pure infrastructure without build artifacts (e.g., VPCs, databases, IAM roles)

Both types use the same workflow orchestration pattern with reusable workflows, providing a consistent deployment flow.

## Multi-Environment Support

**All workflows support deploying to multiple environments simultaneously using a matrix strategy.**

### Key Features

- ✅ **Automatic Environment Discovery**: Detects environments from `.tfvars` files in the `variables/` directory
- ✅ **Parallel Deployment**: All environments (dev, staging, prod) are planned/applied in parallel
- ✅ **Environment-Specific Roles**: Each environment uses its own AWS IAM role for security isolation
- ✅ **Environment-Specific Artifacts**: Separate Terraform plan artifacts per environment
- ✅ **Environment-Specific PR Comments**: Each environment gets its own PR comment with plan results

### Environment Configuration

Environments are automatically discovered based on `.tfvars` files:

```
terraform/your-stack/
  variables/
    dev.tfvars       → Creates "dev" environment
    staging.tfvars   → Creates "staging" environment
    prod.tfvars      → Creates "prod" environment
```

The workflow matrix is generated dynamically

## Architecture Overview

The deployment system uses a **three-tier workflow architecture** that separates concerns and enables reusability:

```
┌─────────────────────────────────────────────────────────────┐
│               Orchestrator Workflow                         │
│                                                             │
│  • Generates environment matrix dynamically                 │
│  • Coordinates workflow execution for all environments      │
│  • Passes parameters between workflows                      │
└────────────┬────────────────────────────┬───────────────────┘
             │                            │
             ▼                            ▼
    ┌────────────────┐           ┌────────────────┐
    │  Build/Push    │           │   Terraform    │
    │   Workflow     │──────────▶│   Workflows    │
    │ (Per Env/Mtx)  │   Image   │  (Per Env)     │
    │                │  Version  │                │
    └────────────────┘           └────────────────┘
```

### Workflow Layers

1. **Orchestrator Layer** - Stack-specific workflows that define what to deploy
   - Generates environment matrix from tfvars files
   - Calls reusable workflows for each environment in parallel
   - Passes outputs between workflow steps

2. **Reusable Workflow Layer** - Generic, parameterized workflows
   - [build_and_push.yml](../.github/workflows/build_and_push.yml) - Docker image building and publishing
   - [terraform_plan.yml](../.github/workflows/terraform_plan.yml) - Infrastructure planning
   - [terraform_apply.yml](../.github/workflows/terraform_apply.yml) - Infrastructure deployment

3. **Tool Layer** - Individual actions and tools
   - Docker Buildx, Trivy, Terraform, Checkov, etc.

## Orchestrator Workflow Types

The repository supports two types of orchestrator workflows based on deployment requirements:

### Container-Based Orchestrators

**Use Case:** Infrastructure that depends on Docker container images

**Examples:**
- Lambda functions using container images
- ECS/Fargate services
- Kubernetes workloads
- Any service that requires a Docker build step


**Job Flow:**
```
generate-matrix → build-and-push (matrix) → terraform-plan (matrix) / terraform-apply (matrix)
```

**Key Characteristics:**
- Includes `build-and-push` job running in a matrix (once per environment)
- Each environment pushes to its own ECR repository
- Passes image version to Terraform via `terraform_vars` parameter
- Coordinates artifact building with infrastructure deployment
- Triggers on both application code AND infrastructure changes


### Infrastructure-Only Orchestrators

**Use Case:** Pure infrastructure without build dependencies

**Examples:**
- Networking (VPCs, subnets, route tables, security groups)
- Foundational resources (S3 buckets, DynamoDB tables)
- IAM roles and policies
- ECR repositories (the repositories themselves, not the images)
- RDS databases
- CloudWatch alarms and logging infrastructure
- Secrets Manager resources

**Reference Workflow:** [terraform_base.yml](../.github/workflows/terraform_base.yml)

**Job Flow:**
```
generate-matrix → terraform-plan (matrix) / terraform-apply (matrix)
```

**Key Characteristics:**
- No `build-and-push` job - goes directly to Terraform workflows
- Simpler and faster execution (no build/test/scan phases)
- Only triggers on infrastructure code changes
- No dynamic Terraform variables for image versions

**Path Triggers:**
```yaml
paths:
  - 'terraform/ai-ordering-base/**'
  - '.github/workflows/terraform_base.yml'
```

### Choosing the Right Orchestrator Type

| Infrastructure | Orchestrator Type | Reason |
|---------------|-------------------|---------|
| Lambda (container image) | Container-Based | Requires Docker image build |
| ECS/Fargate service | Container-Based | Requires Docker image |
| VPC and subnets | Infrastructure-Only | Pure infrastructure |
| RDS database | Infrastructure-Only | AWS managed service |
| S3 buckets | Infrastructure-Only | Pure storage resource |
| IAM roles/policies | Infrastructure-Only | Identity resources |
| ECR repositories | Infrastructure-Only | Container for images, not images themselves |
| DynamoDB tables | Infrastructure-Only | AWS managed database |
| API Gateway | Infrastructure-Only | Unless paired with container-based Lambda |
| CloudWatch resources | Infrastructure-Only | Monitoring infrastructure |

**Decision Rule:** If your Terraform code references a Docker image tag/version variable that needs to be dynamically set, use a container-based orchestrator. Otherwise, use infrastructure-only.

## Complete Deployment Flow

### Container-Based Stack Flow

This section describes the full workflow for container-based stacks with multi-environment support.

#### Pull Request Flow

When you create a PR that modifies application code or infrastructure:

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Pull Request Created                                             │
│    • Triggers on paths: terraform/ai-ordering-lambda/**             │
│                        src/lambda/mock/**                           │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Generate Environment Matrix (generate-matrix job)                │
│    a. Discover Environments                                         │
│       • Checkout code                                               │
│       • Scan variables/ directory for .tfvars files                 │
│       • Extract environment names: [dev, staging, prod]             │
│       • Create JSON matrix: {"environment": ["dev", "staging", ...]}│
│                                                                     │
│    b. Output Configuration                                          │
│       • Matrix for parallel job execution                           │
│       • Static values: AWS_REGION, WORKING_DIR, ECR_REPOSITORY      │
│                                                                     │
│    Example Output:                                                  │
│       matrix: {"environment": ["dev", "staging", "prod"]}           │
│       Found environments: ["dev","staging","prod"]                  │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Build and Push (build-and-push job - MATRIX)                    │
│    Runs in parallel for EACH environment (dev, staging, prod)       │
│                                                                     │
│    For EACH environment:                                            │
│    a. Assume Environment-Specific Role                              │
│       • Uses AWS_ROLE_ARN_dev, AWS_ROLE_ARN_staging, etc.          │
│       • OIDC authentication to environment's AWS account            │
│                                                                     │
│    b. Build Docker Image                                            │
│       • First environment: Full build (~2-5 minutes)                │
│       • Other environments: Cached build (~10-30 seconds)           │
│       • Docker BuildKit layer caching makes this efficient          │
│                                                                     │
│    c. Security Scanning                                             │
│       • Run Trivy vulnerability scan                                │
│       • Fail if CRITICAL or HIGH vulnerabilities found              │
│       • Upload results to GitHub Security tab                       │
│                                                                     │
│    d. Push to Environment's ECR                                     │
│       • Authenticate to environment's ECR                           │
│       • Push multi-platform image to that environment's repo        │
│       • Tags: pr-<number>, sha-<commit>                             │
│                                                                     │
│    e. Output Image Version                                          │
│       • All environments produce same version (e.g., sha-abc1234)   │
│       • Version used by terraform-plan for that environment         │
│                                                                     │
│    Matrix Result:                                                   │
│       ✓ dev     → Built & pushed to dev ECR                         │
│       ✓ staging → Built (cached) & pushed to staging ECR            │
│       ✓ prod    → Built (cached) & pushed to prod ECR               │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. Terraform Plan (terraform-plan job - MATRIX)                    │
│    Runs in parallel for EACH environment (dev, staging, prod)       │
│                                                                     │
│    For EACH environment:                                            │
│    a. Infrastructure Setup                                          │
│       • Checkout code                                               │
│       • Install Terraform 1.11.3                                    │
│       • Authenticate with environment-specific role                 │
│                                                                     │
│    b. Terraform Operations                                          │
│       • Initialize: terraform init -upgrade                         │
│       • Select workspace: terraform workspace select <environment>  │
│       • Format check: terraform fmt -check -recursive               │
│       • Validate: terraform validate                                │
│                                                                     │
│    c. Plan with Environment Variables                               │
│       • Use environment-specific tfvars:                            │
│         -var-file=variables/dev.tfvars (or staging/prod)            │
│       • Pass image version:                                         │
│         -var ai_ordering_lambda_image_version=<image-version>       │
│       • Generate plan output files (tfplan, tfplan.txt, tfplan.json)│
│                                                                     │
│    d. Security and Validation                                       │
│       • Run Checkov security scan on plan                           │
│       • Check for security misconfigurations                        │
│                                                                     │
│    e. Environment-Specific Artifact                                 │
│       • Upload plan artifact with environment in name:              │
│         tfplan-ai-ordering-lambda-pr-<number>-dev                   │
│         tfplan-ai-ordering-lambda-pr-<number>-staging               │
│         tfplan-ai-ordering-lambda-pr-<number>-prod                  │
│       • Retention: 30 days                                          │
│                                                                     │
│    f. Environment-Specific PR Comment                               │
│       • Post separate comment for each environment                  │
│       • Comment identifier includes environment:                    │
│         <!-- terraform-plan-ai-ordering-lambda-dev -->              │
│       • Shows plan results, Checkov status, artifact name           │
│                                                                     │
│    Matrix Result:                                                   │
│       ✓ dev     → Plan complete, artifact uploaded, comment posted  │
│       ✓ staging → Plan complete, artifact uploaded, comment posted  │
│       ✓ prod    → Plan complete, artifact uploaded, comment posted  │
└─────────────────────────────────────────────────────────────────────┘
```

### Merge to Main Flow

When the PR is merged to the main branch:

**Important:** The Docker images were already built and pushed to each environment's ECR during the PR phase. The merge to main only triggers the Terraform apply phase.

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Push to Main Branch                                              │
│    • Triggers on merge commit                                       │
│    • Same path filters apply                                        │
│    • Note: Docker images already exist in all ECRs from PR build    │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Generate Environment Matrix (generate-matrix job)                │
│    • Re-discovers environments from tfvars files                    │
│    • Generates same matrix as PR: [dev, staging, prod]             │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Terraform Apply (terraform-apply job - MATRIX)                  │
│    Runs in parallel for EACH environment (dev, staging, prod)       │
│                                                                     │
│    For EACH environment:                                            │
│    a. PR Artifact Retrieval                                         │
│       • Find merged PR number using GitHub API                      │
│       • Download environment-specific plan artifact:                │
│         tfplan-ai-ordering-lambda-pr-<number>-dev                   │
│         tfplan-ai-ordering-lambda-pr-<number>-staging               │
│         tfplan-ai-ordering-lambda-pr-<number>-prod                  │
│       • This ensures only reviewed plans are applied                │
│       • Plan includes image version from PR build                   │
│                                                                     │
│    b. Infrastructure Setup                                          │
│       • Install Terraform and authenticate with env-specific role   │
│       • Initialize and select environment workspace                 │
│                                                                     │
│    c. Apply Infrastructure Changes                                  │
│       • Execute: terraform apply tfplan                             │
│       • Uses the exact plan from PR (no surprises)                  │
│       • Updates Lambda function with image version from PR          │
│       • Image is already available in environment's ECR             │
│                                                                     │
│    d. Deployment Summary                                            │
│       • Generate GitHub Actions summary for this environment        │
│       • Record applied commit SHA and PR number                     │
│                                                                     │
│    Matrix Result:                                                   │
│       ✓ dev     → Applied successfully                              │
│       ✓ staging → Applied successfully                              │
│       ✓ prod    → Applied successfully                              │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Images Are Pushed During PR (Per Environment)

The workflow pushes images to each environment's ECR during the PR phase for the following reasons:

1. **Environment Isolation:** Each AWS account/environment has its own ECR
2. **Security Boundaries:** Dev role cannot push to prod ECR
3. **Dynamic Tag Generation:** Terraform needs the exact image tag during planning
4. **Plan Accuracy:** The Terraform plan must reference a real, existing image in that environment's ECR
5. **Atomic Deployments:** The image that was tested and scanned is exactly what gets deployed
6. **No Rebuild Required:** Merging to main doesn't require rebuilding the images
7. **Efficient Caching:** First environment builds, others use cache (seconds not minutes)

### Infrastructure-Only Stack Flow

For stacks that contain only infrastructure resources (no Docker images), the workflow is simplified by removing all build steps.

#### Pull Request Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Pull Request Created                                             │
│    • Triggers on paths: terraform/ai-ordering-base/**               │
│                        .github/workflows/terraform_base.yml│
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Generate Environment Matrix (generate-matrix job)                │
│    • Scan variables/ directory for .tfvars files                    │
│    • Create matrix: {"environment": ["dev", "staging", "prod"]}     │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Terraform Plan (terraform-plan job - MATRIX)                    │
│    Runs in parallel for EACH environment (dev, staging, prod)       │
│                                                                     │
│    For EACH environment:                                            │
│    a. Infrastructure Setup                                          │
│       • Checkout code                                               │
│       • Install Terraform 1.11.3                                    │
│       • Authenticate with environment-specific AWS role             │
│                                                                     │
│    b. Terraform Operations                                          │
│       • Initialize: terraform init -upgrade                         │
│       • Select workspace: terraform workspace select <environment>  │
│       • Format check: terraform fmt -check -recursive               │
│       • Validate: terraform validate                                │
│                                                                     │
│    c. Generate Environment-Specific Plan                            │
│       • Use environment-specific tfvars file                        │
│       • No dynamic image version variables needed                   │
│       • Generate plan output files (tfplan, tfplan.txt, tfplan.json)│
│                                                                     │
│    d. Security and Validation                                       │
│       • Run Checkov security scan on plan                           │
│       • Check for security misconfigurations                        │
│                                                                     │
│    e. Artifact and Communication                                    │
│       • Upload environment-specific plan artifact:                  │
│         tfplan-ai-ordering-base-pr-<number>-dev                     │
│         tfplan-ai-ordering-base-pr-<number>-staging                 │
│         tfplan-ai-ordering-base-pr-<number>-prod                    │
│       • Post environment-specific PR comment                        │
│       • Include Checkov results summary                             │
└─────────────────────────────────────────────────────────────────────┘
```

#### Merge to Main Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Push to Main Branch                                              │
│    • Triggers on merge commit                                       │
│    • Path filters apply                                             │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Generate Environment Matrix                                      │
│    • Re-discovers environments from tfvars files                    │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Terraform Apply (terraform-apply job - MATRIX)                  │
│    Runs in parallel for EACH environment (dev, staging, prod)       │
│                                                                     │
│    For EACH environment:                                            │
│    a. PR Artifact Retrieval                                         │
│       • Find merged PR number using GitHub API                      │
│       • Download environment-specific pre-approved plan artifact    │
│       • This ensures only reviewed plans are applied                │
│                                                                     │
│    b. Infrastructure Setup                                          │
│       • Install Terraform and authenticate to environment's AWS     │
│       • Initialize and select workspace                             │
│                                                                     │
│    c. Apply Infrastructure Changes                                  │
│       • Execute: terraform apply tfplan                             │
│       • Uses the exact plan from PR (no surprises)                  │
│       • Deploy infrastructure resources to AWS                      │
│                                                                     │
│    d. Deployment Summary                                            │
│       • Generate GitHub Actions summary                             │
│       • Record applied commit SHA and PR number                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Differences from Container-Based Flow:**
- No build-and-push job
- No test/lint/scan phases for application code
- No dynamic Terraform variables for image versions
- Faster execution
- Only infrastructure code changes trigger the workflow

## Environment Configuration

### GitHub Repository Variables

Set in **Settings → Secrets and variables → Actions → Variables**:

#### Environment-Specific Role ARNs (Required)

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ROLE_ARN_dev` | Dev environment OIDC role | `arn:aws:iam::123456789:role/github-dev` |
| `AWS_ROLE_ARN_staging` | Staging environment OIDC role | `arn:aws:iam::234567890:role/github-staging` |
| `AWS_ROLE_ARN_prod` | Production environment OIDC role | `arn:aws:iam::345678901:role/github-prod` |

#### Static Configuration Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_REGION` | Default deployment region | `us-east-1` |
| `NETWORK_AWS_REGION` | Network stack region | `us-east-2` |

**Important:** Variable names must match the pattern `<PREFIX>_AWS_ROLE_ARN_{environment}` where `{environment}` exactly matches the tfvars filename (without `.tfvars` extension).

**Example:**
- `dev.tfvars` → requires `AWS_ROLE_ARN_dev`
- `staging.tfvars` → requires `AWS_ROLE_ARN_staging`
- `prod.tfvars` → requires `AWS_ROLE_ARN_prod`

### Stack-Specific Configuration

```yaml
env:
  AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
  WORKING_DIR: 'terraform/ai-ordering-lambda'
  ECR_REPOSITORY: 'ai-ordering-mock'
  DOCKERFILE_PATH: 'src/lambda/mock/Dockerfile'
```

**Note:** `ENVIRONMENT` is no longer hardcoded - it's dynamically discovered from tfvars files!

### Terraform Variable Files

Environment-specific variables in `terraform/ai-ordering-lambda/variables/<environment>.tfvars`:

**Example: `dev.tfvars`**
```hcl
environment = "dev"
aws_region  = "us-east-1"

ecr_repositories = {
  "ai-ordering-mock" = {
    image_tag_mutability = "IMMUTABLE"
    image_scanning_configuration = {
      scan_on_push = true
    }
  }
}

# This is passed dynamically by the workflow
# ai_ordering_lambda_image_version = "sha-abc1234"
```

**Example: `prod.tfvars`**
```hcl
environment = "prod"
aws_region  = "us-east-1"

ecr_repositories = {
  "ai-ordering-mock" = {
    image_tag_mutability = "IMMUTABLE"
    image_scanning_configuration = {
      scan_on_push = true
    }
  }
}

# Production-specific overrides
lambda_memory_size = 512
lambda_timeout = 30
```

## Creating New Container-Based Stacks with Multi-Environment Support

To create a new stack that follows this pattern:

### 1. Create Terraform Module

```
terraform/
  your-new-stack/
    main.tf
    variables.tf      # Include image_version variable
    outputs.tf
    ecr.tf            # ECR repository definition
    lambda.tf         # Or ECS, etc.
    variables/        # Environment-specific configs
      dev.tfvars
      staging.tfvars
      prod.tfvars
```

### 2. Create Application Code

```
src/
  your-app/
    Dockerfile
    app/
      # Application code
```

### 3. Create Orchestrator Workflow

Create `.github/workflows/terraform_your_new_stack.yml`:

```yaml
name: Terraform Your New Stack

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/your-new-stack/**'
      - 'src/your-app/**'
      - '.github/workflows/terraform_your_new_stack.yml'
  push:
    branches: [main]
    paths:
      - 'terraform/your-new-stack/**'
      - 'src/your-app/**'
      - '.github/workflows/terraform_your_new_stack.yml'

env:
  AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
  TERRAFORM_VERSION: '1.11.3'
  WORKING_DIR: 'terraform/your-new-stack'
  ECR_REPOSITORY: 'your-app-repo'
  DOCKERFILE_PATH: 'src/your-app/Dockerfile'

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write
  actions: read

jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      AWS_REGION: ${{ steps.static-outputs.outputs.AWS_REGION }}
      WORKING_DIR: ${{ steps.static-outputs.outputs.WORKING_DIR }}
      ECR_REPOSITORY: ${{ steps.static-outputs.outputs.ECR_REPOSITORY }}
      DOCKERFILE_PATH: ${{ steps.static-outputs.outputs.DOCKERFILE_PATH }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Generate environment matrix from tfvars files
        id: set-matrix
        run: |
          # Find all .tfvars files in the variables directory
          TFVARS_FILES=$(find "${{ env.WORKING_DIR }}/variables" -type f -name "*.tfvars" -exec basename {} .tfvars \; | sort)

          # Convert to JSON array
          ENVIRONMENTS=$(echo "$TFVARS_FILES" | jq -R -s -c 'split("\n") | map(select(length > 0))')

          echo "Found environments: $ENVIRONMENTS"
          echo "matrix={\"environment\":$ENVIRONMENTS}" >> $GITHUB_OUTPUT

      - name: Output static values
        id: static-outputs
        env:
          AWS_REGION: ${{ env.AWS_REGION }}
          WORKING_DIR: ${{ env.WORKING_DIR }}
          ECR_REPOSITORY: ${{ env.ECR_REPOSITORY }}
          DOCKERFILE_PATH: ${{ env.DOCKERFILE_PATH }}
        run: |
          echo "AWS_REGION=$AWS_REGION" >> $GITHUB_OUTPUT
          echo "WORKING_DIR=$WORKING_DIR" >> $GITHUB_OUTPUT
          echo "ECR_REPOSITORY=$ECR_REPOSITORY" >> $GITHUB_OUTPUT
          echo "DOCKERFILE_PATH=$DOCKERFILE_PATH" >> $GITHUB_OUTPUT

  build-and-push:
    name: Build and push - ${{ matrix.environment }}
    needs: [generate-matrix]
    if: github.event_name == 'pull_request'
    uses: ./.github/workflows/build_and_push.yml
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ vars[format('AWS_ROLE_ARN_{0}', matrix.environment)] }}
      aws_region: ${{ needs.generate-matrix.outputs.AWS_REGION}}
      ecr_repository: ${{ needs.generate-matrix.outputs.ECR_REPOSITORY }}
      dockerfile_path: ${{ needs.generate-matrix.outputs.DOCKERFILE_PATH }}
      docker_platforms: "linux/amd64"
      docker_provenance: "false"
    secrets: inherit

  terraform-plan:
    name: Terraform plan - ${{ matrix.environment }}
    needs: [generate-matrix, build-and-push]
    uses: ./.github/workflows/terraform_plan.yml
    if: github.event_name == 'pull_request'
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ vars[format('AWS_ROLE_ARN_{0}', matrix.environment)] }}
      aws_region: ${{ needs.generate-matrix.outputs.AWS_REGION}}
      working_dir: ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment: ${{ matrix.environment }}
      terraform_vars: '-var your_app_image_version=${{ needs.build-and-push.outputs.image-version }}'
    secrets: inherit

  terraform-apply:
    name: Terraform Apply - ${{ matrix.environment }}
    needs: [generate-matrix]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ./.github/workflows/terraform_apply.yml
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ vars[format('AWS_ROLE_ARN_{0}', matrix.environment)] }}
      aws_region: ${{ needs.generate-matrix.outputs.AWS_REGION}}
      working_dir: ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment: ${{ matrix.environment }}
    secrets: inherit
```

### 4. Configure GitHub Variables

Add environment-specific role ARNs to GitHub:

**Settings → Secrets and variables → Actions → Variables → New repository variable**

```
AWS_ROLE_ARN_dev      = arn:aws:iam::123456789:role/github-dev
AWS_ROLE_ARN_staging  = arn:aws:iam::234567890:role/github-staging
AWS_ROLE_ARN_prod     = arn:aws:iam::345678901:role/github-prod
```

### 5. Key Customization Points

- **Path triggers:** Update to match your directory structure
- **ECR_REPOSITORY:** Your ECR repository name (same name in all environments)
- **DOCKERFILE_PATH:** Path to your Dockerfile
- **WORKING_DIR:** Your Terraform module directory
- **terraform_vars:** Update variable name to match your Terraform variable
- **Variable pattern:** Use `AWS_ROLE_ARN_{environment}` for role naming

## Creating New Infrastructure-Only Stacks with Multi-Environment Support

To create a new stack for pure infrastructure without Docker images:

### 1. Create Terraform Module

```
terraform/
  your-infrastructure-stack/
    main.tf
    variables.tf      # No image version variables needed
    outputs.tf
    networking.tf     # Example: VPC resources
    iam.tf           # Example: IAM roles
    storage.tf       # Example: S3, DynamoDB
    variables/
      dev.tfvars
      staging.tfvars
      prod.tfvars
```

### 2. Create Orchestrator Workflow

Create `.github/workflows/terraform_your_infrastructure_stack.yml`:

```yaml
name: Terraform Your Infrastructure Stack

on:
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/your-infrastructure-stack/**'
      - '.github/workflows/terraform_your_infrastructure_stack.yml'
  push:
    branches:
      - main
    paths:
      - 'terraform/your-infrastructure-stack/**'
      - '.github/workflows/terraform_your_infrastructure_stack.yml'

env:
  AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
  TERRAFORM_VERSION: '1.11.3'
  WORKING_DIR: 'terraform/your-infrastructure-stack'

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write
  actions: read

jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      AWS_REGION: ${{ steps.static-outputs.outputs.AWS_REGION }}
      WORKING_DIR: ${{ steps.static-outputs.outputs.WORKING_DIR }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Generate environment matrix from tfvars files
        id: set-matrix
        run: |
          # Find all .tfvars files in the variables directory
          TFVARS_FILES=$(find "${{ env.WORKING_DIR }}/variables" -type f -name "*.tfvars" -exec basename {} .tfvars \; | sort)

          # Convert to JSON array
          ENVIRONMENTS=$(echo "$TFVARS_FILES" | jq -R -s -c 'split("\n") | map(select(length > 0))')

          echo "Found environments: $ENVIRONMENTS"
          echo "matrix={\"environment\":$ENVIRONMENTS}" >> $GITHUB_OUTPUT

      - name: Output static values
        id: static-outputs
        env:
          AWS_REGION: ${{ env.AWS_REGION }}
          WORKING_DIR: ${{ env.WORKING_DIR }}
        run: |
          echo "AWS_REGION=$AWS_REGION" >> $GITHUB_OUTPUT
          echo "WORKING_DIR=$WORKING_DIR" >> $GITHUB_OUTPUT

  terraform-plan:
    name: Terraform plan - ${{ matrix.environment }}
    needs: [generate-matrix]
    uses: ./.github/workflows/terraform_plan.yml
    if: github.event_name == 'pull_request'
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ vars[format('AWS_ROLE_ARN_{0}', matrix.environment)] }}
      aws_region: ${{ needs.generate-matrix.outputs.AWS_REGION}}
      working_dir: ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment: ${{ matrix.environment }}
    secrets: inherit

  terraform-apply:
    name: Terraform Apply - ${{ matrix.environment }}
    needs: [generate-matrix]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ./.github/workflows/terraform_apply.yml
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ vars[format('AWS_ROLE_ARN_{0}', matrix.environment)] }}
      aws_region: ${{ needs.generate-matrix.outputs.AWS_REGION}}
      working_dir: ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment: ${{ matrix.environment }}
    secrets: inherit
```

### 3. Configure GitHub Variables

```
AWS_ROLE_ARN_dev      = arn:aws:iam::123456789:role/github-dev
AWS_ROLE_ARN_staging  = arn:aws:iam::234567890:role/github-staging
AWS_ROLE_ARN_prod     = arn:aws:iam::345678901:role/github-prod
```

## Adding a New Environment

To add a new environment (e.g., `qa`):

### 1. Create Terraform Variables File

```bash
cp terraform/your-stack/variables/dev.tfvars terraform/your-stack/variables/qa.tfvars
# Edit qa.tfvars with environment-specific values
```

### 2. Add GitHub Variable for Role ARN

Add `AWS_ROLE_ARN_qa` to GitHub repository variables.

### 3. Create AWS IAM Role

Create an OIDC-enabled IAM role in the QA AWS account with appropriate permissions.

### 4. That's It!

The workflow will automatically:
- Discover the new `qa.tfvars` file
- Add `qa` to the environment matrix
- Run build/plan/apply for QA alongside other environments

**No workflow YAML changes needed!**

## Troubleshooting

### Build Fails on Tests

**Symptoms:** Build workflow fails during test phase

**Solutions:**
- Review test output in workflow logs
- Run tests locally: `uv sync && uv tool run ruff check`
- Check for import errors or missing dependencies
- Verify Python version matches workflow (3.12 default)

### Trivy Security Scan Failures

**Symptoms:** Build succeeds but Trivy scan fails

**Solutions:**
- Review vulnerability report in workflow logs
- Update base image in Dockerfile to latest patched version
- Check if vulnerabilities are in OS packages or Python dependencies
- Temporarily adjust `trivy_severity` input (not recommended for production)

### Apply Cannot Find Plan Artifact

**Symptoms:** terraform-apply fails with "artifact not found" for specific environment

**Solutions:**
- Verify PR was merged (not closed without merge)
- Check environment-specific artifact was uploaded in PR workflow
- Confirm artifact name matches expected pattern: `tfplan-<stack>-pr-<number>-<environment>`
- Check artifact hasn't exceeded 30-day retention
- Verify environment name in artifact exactly matches tfvars filename

### Image Not Updating in Lambda

**Symptoms:** Code changes deployed but Lambda still runs old version

**Solutions:**
- Check Lambda function configuration in AWS console
- Verify image tag in Terraform matches pushed tag
- Confirm ECR image was actually pushed to correct environment's ECR (check workflow logs)
- Review Terraform apply output for actual changes made
- Ensure environment-specific role has ECR permissions

### Matrix Job Fails for One Environment

**Symptoms:** Dev works but staging/prod fails

**Solutions:**
- Check if GitHub variable exists for that environment (e.g., `AWS_ROLE_ARN_staging`)
- Verify IAM role ARN is correct and accessible
- Check if ECR repository exists in that environment's AWS account
- Review AWS permissions for that environment's role
- Look at workflow logs for environment-specific errors

### "Role ARN not found" Error

**Symptoms:** Workflow fails with variable not found

**Solutions:**
- Verify GitHub variable name matches pattern exactly:
  - `AWS_ROLE_ARN_{environment}` (e.g., `AWS_ROLE_ARN_dev`)
- Environment name must exactly match tfvars filename (case-sensitive)
- Variables must be set at **repository** level, not environment level
- Check variable is not empty or null

### Docker Build Cache Not Working

**Symptoms:** All environment builds take full time

**Solutions:**
- Verify Dockerfile hasn't changed between environments
- Check if build context is identical
- Ensure Docker BuildKit is enabled (it should be by default)
- Look for errors in first (dev) build that might prevent caching
- Consider if GitHub Actions runner was recycled between builds