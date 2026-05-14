# Deployment Process for Infrastructure Stacks

This guide explains the complete process for updating and deploying infrastructure stacks in this repository. All stacks here are **infrastructure-only** — pure Terraform-managed AWS resources (e.g., VPCs, IAM roles, S3 buckets, KMS keys) with no application code or container build step.

The deployment model uses a reviewed-plan handoff: PRs generate a Terraform plan artifact, reviewers approve it, and the merge to `main` applies that exact plan — no replanning at apply time.

## Multi-Environment Support

**All workflows support deploying to multiple environments simultaneously using a matrix strategy.**

### Key Features

- **Automatic Environment Discovery**: Detects environments from `.tfvars` files in the `variables/` directory
- **Parallel Deployment**: All environments are planned/applied in parallel
- **Cross-Account Isolation**: A single central CI role assumes a dedicated per-account execution role chosen by the environment's tfvars
- **Environment-Specific Artifacts**: Separate Terraform plan artifacts per environment
- **Environment-Specific PR Comments**: Each environment gets its own PR comment with plan results

### Environment Configuration

Environments are automatically discovered based on `.tfvars` files:

```
terraform/your-stack/
  variables/
    dev.tfvars       → Creates "dev" environment
    prod.tfvars      → Creates "prod" environment
    shared.tfvars    → Creates "shared" environment
```

The workflow matrix is generated dynamically from the contents of `variables/`.

## Architecture Overview

The deployment system uses a **two-tier workflow architecture** that separates concerns and enables reusability:

```
┌─────────────────────────────────────────────────────────────┐
│               Orchestrator Workflow                         │
│                                                             │
│  • Generates environment matrix dynamically                 │
│  • Coordinates workflow execution for all environments      │
│  • Passes parameters between workflows                      │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                  ┌────────────────────┐
                  │     Terraform      │
                  │     Workflows      │
                  │     (Per Env)      │
                  └────────────────────┘
```

### Workflow Layers

1. **Orchestrator Layer** — Stack-specific workflows that define what to deploy
   - Generate environment matrix from tfvars files
   - Call reusable workflows for each environment in parallel
   - Pass outputs between workflow steps

2. **Reusable Workflow Layer** — Generic, parameterized workflows
   - [terraform_plan.yml](../.github/workflows/terraform_plan.yml) — Infrastructure planning
   - [terraform_apply.yml](../.github/workflows/terraform_apply.yml) — Infrastructure deployment

## Authentication Model

This repository uses a **hub-and-spoke** assume-role chain. There is **no per-environment GitHub OIDC role** — every workflow run authenticates the same way and Terraform itself does the cross-account hop.

```
GitHub Actions (OIDC)
        │
        ▼
  Central CI role          ◀── vars.AWS_ROLE_ARN
  (services account)           one role, shared across all stacks + environments
        │
        │   provider "aws" { assume_role { role_arn = ... } }
        ▼
  region-20-terraform-execution-role
  (dev / prod / shared / ... target account)   ◀── selected by account_id in tfvars
        │
        ▼
  AWS resources for the env
```

### How it works

1. **GitHub → central CI role.** The orchestrator pulls a single repo-level variable, `vars.AWS_ROLE_ARN`, and forwards it to the reusable plan/apply workflows. `aws-actions/configure-aws-credentials` exchanges the OIDC token for credentials for that role. The same role is used for every environment.

2. **Central role → per-account execution role.** Each stack's `providers.tf` configures the AWS provider with an `assume_role` block that targets a dedicated execution role in the target account:

   ```hcl
   provider "aws" {
     region = var.aws_region

     assume_role {
       role_arn = "arn:aws:iam::${var.account_id}:role/region-20-terraform-execution-role"
     }
   }
   ```

3. **`account_id` selects the target account.** `account_id` is set per environment in `terraform/<stack>/variables/<env>.tfvars`. Switching environments switches which account Terraform deploys into — the workflow itself doesn't need to change.

### Why this model

- One CI role to grant trust to from GitHub OIDC. Adding a new target account only requires creating the execution role in that account and trusting the central CI role — no GitHub config change.
- The central CI role's only AWS permission is `sts:AssumeRole` against the per-account execution roles, so a leaked OIDC token can't act on any account directly.
- Per-account roles are scoped to the privileges that stack needs in that account.

## Orchestrator Workflows

Each stack has its own orchestrator workflow that triggers on changes to that stack's directory.

**Use Case:** Pure infrastructure without build dependencies

**Examples:**
- Networking (VPCs, subnets, route tables, security groups)
- Foundational resources (S3 buckets, DynamoDB tables, KMS keys)
- IAM roles and policies
- Audit logging infrastructure
- RDS databases
- CloudWatch alarms and logging infrastructure
- Secrets Manager resources

**Reference Workflows:**
- [terraform_base.yml](../.github/workflows/terraform_base.yml)
- [terraform_audit.yml](../.github/workflows/terraform_audit.yml)
- [terraform_networking.yml](../.github/workflows/terraform_networking.yml)

**Job Flow:**
```
generate-matrix → terraform-plan (matrix) / terraform-apply (matrix)
```

**Key Characteristics:**
- Triggers only on infrastructure code changes (paths under the stack directory)
- Discovers environments from `variables/*.tfvars` at runtime
- Plan runs on pull requests; apply runs on push to `main`

**Example Path Triggers:**
```yaml
paths:
  - 'terraform/base/**'
  - '.github/workflows/terraform_base.yml'
```

## Complete Deployment Flow

### Pull Request Flow

When you create a PR that modifies a stack:

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Pull Request Created                                             │
│    • Triggers on paths: terraform/<stack-name>/**                   │
│                        .github/workflows/terraform_<stack>.yml      │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Generate Environment Matrix (generate-matrix job)                │
│    • Scan variables/ directory for .tfvars files                    │
│    • Create matrix: {"environment": ["dev", "prod", "shared"]}      │
└────────────────────┬────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. Terraform Plan (terraform-plan job - MATRIX)                     │
│    Runs in parallel for EACH environment                            │
│                                                                     │
│    For EACH environment:                                            │
│    a. Authentication                                                │
│       • Checkout code                                               │
│       • Install Terraform                                           │
│       • OIDC-assume the central CI role (vars.AWS_ROLE_ARN)         │
│       • Provider chain-assumes the per-account execution role       │
│         using account_id from <env>.tfvars                          │
│                                                                     │
│    b. Terraform Operations                                          │
│       • Initialize: terraform init                                  │
│       • Select workspace: terraform workspace select <environment>  │
│       • Format check: terraform fmt -check -recursive               │
│       • Validate: terraform validate                                │
│                                                                     │
│    c. Generate Environment-Specific Plan                            │
│       • Use environment-specific tfvars file                        │
│       • Generate plan output files (tfplan, tfplan.txt, tfplan.json)│
│                                                                     │
│    d. Security and Validation                                       │
│       • Run Checkov security scan on plan                           │
│                                                                     │
│    e. Artifact and Communication                                    │
│       • Upload environment-specific plan artifact:                  │
│         tfplan-<stack>-pr-<number>-dev                              │
│         tfplan-<stack>-pr-<number>-prod                             │
│         tfplan-<stack>-pr-<number>-shared                           │
│       • Post environment-specific PR comment                        │
│       • Include Checkov results summary                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Merge to Main Flow

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
│ 3. Terraform Apply (terraform-apply job - MATRIX)                   │
│    Runs in parallel for EACH environment                            │
│                                                                     │
│    For EACH environment:                                            │
│    a. PR Artifact Retrieval                                         │
│       • Find merged PR number using GitHub API                      │
│       • Download environment-specific pre-approved plan artifact    │
│       • This ensures only reviewed plans are applied                │
│                                                                     │
│    b. Authentication                                                │
│       • OIDC-assume the central CI role                             │
│       • Provider chain-assumes the per-account execution role       │
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

## Environment Configuration

### GitHub Repository Variables

Set in **Settings → Secrets and variables → Actions → Variables**:

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ROLE_ARN` | Central GitHub-OIDC CI role in the services account. The same value is used for every environment — environment isolation comes from the per-account assume-role chain in each stack's `providers.tf`. | `arn:aws:iam::471624149663:role/region-20-github-oidc` |
| `AWS_REGION` | Default deployment region | `us-east-1` |
| `NETWORK_AWS_REGION` | Network stack region override (optional) | `us-east-2` |
| `TERRAFORM_VERSION` | Terraform version override (optional) | `1.11.3` |

There are **no** `AWS_ROLE_ARN_<env>` variables — the env is resolved at the Terraform layer via `account_id` in the tfvars.

### AWS Prerequisites (per target account)

In every account this repo deploys into (dev, prod, shared, …), an execution role named `region-20-terraform-execution-role` must exist with:

- A trust policy that allows `sts:AssumeRole` from the central CI role (`vars.AWS_ROLE_ARN`)
- Permissions sufficient for the stacks that target that account

Once that role exists, no GitHub-side wiring is required to add the account — the stack just references it by `account_id` in tfvars.

### Stack-Specific Configuration

```yaml
env:
  AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
  AWS_ROLE_ARN: ${{ vars.AWS_ROLE_ARN }}
  TERRAFORM_VERSION: ${{ vars.TERRAFORM_VERSION || '1.11.3' }}
  WORKING_DIR: 'terraform/<stack-name>'
```

**Note:** `ENVIRONMENT` is not hardcoded — it's dynamically discovered from tfvars files.

### Terraform Variable Files

Environment-specific variables live in `terraform/<stack-name>/variables/<environment>.tfvars`. Each file **must** set `account_id` — that's how the AWS provider knows which account to chain-assume into.

**Example: `dev.tfvars`**
```hcl
environment  = "dev"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "784590287037"

# stack-specific vars below...
```

**Example: `prod.tfvars`**
```hcl
environment  = "prod"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "029750300494"

# stack-specific vars below...
```

### State Backend

Remote state for every stack lives in a single S3 bucket (`region-20-tf-state`) in the services account, with one key per stack. The backend block is **hardcoded** in each stack's `terraform.tf` — there are no per-env state backend variables:

```hcl
backend "s3" {
  bucket       = "region-20-tf-state"
  key          = "<stack-name>/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
  kms_key_id   = "<services-account-kms-key-arn>"
}
```

Per-environment isolation inside that shared backend is provided by Terraform workspaces (`terraform workspace select <env>`), which the plan/apply workflows handle automatically.

## Creating a New Infrastructure Stack

A stack template is provided at [.github/workflows/templates/terraform_stack.yml](../.github/workflows/templates/terraform_stack.yml). Follow these steps to add a new stack.

### 1. Create the Terraform Module

```
terraform/
  your-stack/
    main.tf
    variables.tf     # must include account_id (string)
    providers.tf     # assume_role into region-20-terraform-execution-role
    terraform.tf     # backend "s3" block + required_providers
    outputs.tf
    variables/
      dev.tfvars     # must set account_id
      prod.tfvars    # must set account_id
```

`providers.tf` should follow the same pattern as the existing stacks:

```hcl
provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/region-20-terraform-execution-role"
  }

  default_tags {
    tags = {
      Environment = var.environment
      Team        = var.team
      ManagedBy   = "Terraform"
      Stack       = "your-stack"
    }
  }
}
```

### 2. Create the Orchestrator Workflow

Copy the existing `terraform_base.yml` / `terraform_audit.yml` / `terraform_networking.yml` pattern and swap in your stack name. The orchestrator only needs to forward `vars.AWS_ROLE_ARN` and the stack's `WORKING_DIR`:

```yaml
name: Terraform - <stack-name>
on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/<stack-name>/**'
      - '.github/workflows/terraform_<stack-name>.yml'
  push:
    branches: [main]
    paths:
      - 'terraform/<stack-name>/**'
      - '.github/workflows/terraform_<stack-name>.yml'

env:
  AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
  AWS_ROLE_ARN: ${{ vars.AWS_ROLE_ARN }}
  TERRAFORM_VERSION: ${{ vars.TERRAFORM_VERSION || '1.11.3' }}
  WORKING_DIR: 'terraform/<stack-name>'

permissions:
  id-token: write
  contents: read
  pull-requests: write
  actions: read
  deployments: write

jobs:
  generate-matrix:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      AWS_REGION: ${{ steps.static-outputs.outputs.AWS_REGION }}
      AWS_ROLE_ARN: ${{ steps.static-outputs.outputs.AWS_ROLE_ARN }}
      WORKING_DIR: ${{ steps.static-outputs.outputs.WORKING_DIR }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{github.ref}}
      - name: Generate environment matrix from tfvars files
        id: set-matrix
        run: |
          TFVARS_FILES=$(find "${{ env.WORKING_DIR }}/variables" -type f -name "*.tfvars" -exec basename {} .tfvars \; | sort)
          ENVIRONMENTS=$(echo "$TFVARS_FILES" | jq -R -s -c 'split("\n") | map(select(length > 0))')
          echo "matrix={\"environment\":$ENVIRONMENTS}" >> $GITHUB_OUTPUT
      - name: Output static values
        id: static-outputs
        env:
          AWS_REGION: ${{ env.AWS_REGION }}
          AWS_ROLE_ARN: ${{ env.AWS_ROLE_ARN }}
          WORKING_DIR: ${{ env.WORKING_DIR }}
        run: |
          echo "AWS_REGION=$AWS_REGION" >> $GITHUB_OUTPUT
          echo "AWS_ROLE_ARN=$AWS_ROLE_ARN" >> $GITHUB_OUTPUT
          echo "WORKING_DIR=$WORKING_DIR" >> $GITHUB_OUTPUT

  terraform-plan:
    name: Terraform plan - ${{ matrix.environment }}
    needs: [generate-matrix]
    if: github.event_name == 'pull_request'
    uses: ./.github/workflows/terraform_plan.yml
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ needs.generate-matrix.outputs.AWS_ROLE_ARN }}
      aws_region:   ${{ needs.generate-matrix.outputs.AWS_REGION }}
      working_dir:  ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment:  ${{ matrix.environment }}

  terraform-apply:
    name: Terraform Apply - ${{ matrix.environment }}
    needs: [generate-matrix]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ./.github/workflows/terraform_apply.yml
    strategy:
      matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
      fail-fast: false
    with:
      aws_role_arn: ${{ needs.generate-matrix.outputs.AWS_ROLE_ARN }}
      aws_region:   ${{ needs.generate-matrix.outputs.AWS_REGION }}
      working_dir:  ${{ needs.generate-matrix.outputs.WORKING_DIR }}
      environment:  ${{ matrix.environment }}
    secrets: inherit
```

### 3. Confirm Repository Variables Exist

Because every stack reuses the same central CI role, you usually don't need to add anything new — just confirm:

- `AWS_ROLE_ARN` (central CI role) is already set
- `AWS_REGION` is set (or fall back to the workflow default)

### 4. Key Customization Points

- **Path triggers:** Update to match your stack directory
- **WORKING_DIR:** Your Terraform stack directory
- **AWS_REGION:** Override at the workflow `env:` block if the stack should deploy to a non-default region
- **providers.tf:** Update the `Stack` tag and confirm the `assume_role.role_arn` uses `var.account_id`
- **Backend key:** Set a unique `key` in `terraform.tf` so this stack doesn't collide with others in `region-20-tf-state`

## Adding a New Environment

To add a new environment (e.g., `qa`):

### 1. Provision the target account's execution role

In the QA AWS account, create a role named `region-20-terraform-execution-role` whose trust policy allows `sts:AssumeRole` from the central CI role (`vars.AWS_ROLE_ARN`), with the permissions needed for the stacks that will target QA.

### 2. Create the tfvars file

```bash
cp terraform/your-stack/variables/dev.tfvars terraform/your-stack/variables/qa.tfvars
# Edit qa.tfvars and set:
#   environment = "qa"
#   account_id  = "<qa-account-id>"
# plus any environment-specific values
```

### 3. That's It

The workflow will automatically:
- Discover the new `qa.tfvars` file
- Add `qa` to the environment matrix
- Run plan/apply for QA — the AWS provider in `providers.tf` will chain into the QA account using `var.account_id`

**No workflow YAML changes and no new GitHub variables are needed.**

## Troubleshooting

### Apply Cannot Find Plan Artifact

**Symptoms:** terraform-apply fails with "artifact not found" for a specific environment

**Solutions:**
- Verify the PR was merged (not closed without merge)
- Check that the environment-specific artifact was uploaded in the PR workflow
- Confirm artifact name matches expected pattern: `tfplan-<stack>-pr-<number>-<environment>`
- Check that the artifact hasn't exceeded the 30-day retention
- Verify the environment name in artifact exactly matches the tfvars filename

### Matrix Job Fails for One Environment

**Symptoms:** Dev works but prod/shared fails

**Solutions:**
- Confirm `region-20-terraform-execution-role` exists in the target account and trusts the central CI role
- Check that `account_id` in the env's `.tfvars` is correct
- Review AWS CloudTrail in the target account for the `AssumeRole` denial event
- Look at workflow logs for the exact `sts:AssumeRole` failure message

### "AccessDenied" on the chained AssumeRole

**Symptoms:** Plan/apply fails at provider init with `AccessDenied` when assuming `region-20-terraform-execution-role`

**Solutions:**
- Verify the target account's execution role trust policy includes the central CI role ARN exactly (no typos)
- Confirm `vars.AWS_ROLE_ARN` resolves to the central CI role you expect (echo it from the workflow if needed)
- If the central role has a permissions boundary, ensure it allows `sts:AssumeRole` to the target role pattern

### "Role ARN not found" Error

**Symptoms:** Workflow fails with `vars.AWS_ROLE_ARN` empty

**Solutions:**
- Confirm `AWS_ROLE_ARN` is set at the **repository** Actions Variables level
- Check the variable is not empty or null
- Note: there are no per-env `AWS_ROLE_ARN_<env>` variables in this model — only the single central one

### Checkov Scan Failures

**Symptoms:** Plan succeeds but Checkov scan fails on the PR

**Solutions:**
- Review the Checkov findings in workflow logs and the PR comment
- Fix the underlying misconfiguration in your Terraform code
- If a finding is a known false positive, add a skip in `.config/.checkov.yaml` (repo-wide) or an inline `#checkov:skip=<id>: <reason>` (per resource) with justification
