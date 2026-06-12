# General Checks and Tests Workflow

> **In plain terms:** This is the non-Terraform half of the pull-request safety inspection. It does two things on every pull request, with **no AWS access**: it checks that YAML files (such as the workflow files themselves) are well-formed (yamllint), and it scans the whole repository for accidentally committed secrets like passwords or access keys (Gitleaks). If either finds a problem, the pull request is blocked until it is fixed.
>
> New to the project? See the [documentation home](README.md) and the [Making Infrastructure Changes guide](kt-02-making-infrastructure-changes.md) for how these checks fit into your day-to-day workflow.

## Overview

This is a **reusable workflow** that performs general code quality and security checks that don't require AWS credentials. It's designed to be called by other workflows to ensure code meets quality standards before deployment.

**Workflow File:** [.github/workflows/general_checks.yaml](../.github/workflows/general_checks.yaml)

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `path` | string | `"."` | Directory path to check (relative to repository root) |

## Required Permissions

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | write | Access and potentially modify repository content |
| `pull-requests` | write | Comment on pull requests with results |
| `id-token` | write | For potential OIDC usage in calling workflows |

## Jobs

### Job 1: YAML Lint

Validates YAML file syntax and formatting across the repository.

#### Steps:

1. **Checkout source code**
   - Uses: `actions/checkout@v4`
   - Fetches repository code

2. **Verify yamllint config file**
   - Checks if `.config/.yamllint.yaml` exists locally
   - If not found, clones config from central repository
   - Uses sparse checkout to fetch only the config file
   - Requires: `AUTO_SHIPIT` secret for private repo access

3. **Run Yamllint**
   - Installs: `yamllint==1.35.1`
   - Command: `yamllint --strict --config-file .config/.yamllint.yaml {path}`
   - Checks all YAML files in specified path

#### What It Checks

- Syntax errors
- Formatting consistency
- Indentation issues
- Line length
- Trailing spaces
- Document markers
- Duplicate keys

### Job 2: Detect Secrets (Gitleaks)

Scans the entire repository for exposed secrets and credentials.

#### Steps:

1. **Checkout repo**
   - Uses: `actions/checkout@v4`
   - Full checkout for complete history scan

2. **Install and Run Gitleaks**
   - Installs Homebrew on Ubuntu runner
   - Installs Gitleaks via Homebrew
   - Runs scan: `gitleaks dir --redact --verbose`

#### What It Detects

- AWS access keys and secret keys
- API keys and tokens
- Private keys (RSA, SSH, etc.)
- Database connection strings
- OAuth tokens
- Credit card numbers
- Generic secrets and passwords
- 100+ other secret patterns

## Related Workflows

- [terraform_checks.md](terraform_checks.md) - Terraform format, validate, lint, and security scan
- [terraform_pull_request.md](terraform_pull_request.md) - Main PR workflow that calls this one
- [kt-02-making-infrastructure-changes.md](kt-02-making-infrastructure-changes.md) - Running these checks locally before pushing
- [README.md](README.md) - Documentation home
