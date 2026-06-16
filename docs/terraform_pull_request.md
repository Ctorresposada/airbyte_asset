# Terraform CI Pull Request Workflow

> **In plain terms:** This is the master "gatekeeper" that runs whenever you open a pull request. It does not do any work itself — instead it calls the two checking workflows ([Terraform Checks](terraform_checks.md) and [General Checks](general_checks.md)) and runs them in parallel for fast feedback. None of these checks touch AWS; they only read and validate the code. The pull request can merge only after every check passes. This doc also lists the recommended branch-protection settings that enforce that rule.
>
> New to the project? Start at the [documentation home](README.md) and the [Making Infrastructure Changes guide](kt-02-making-infrastructure-changes.md).

## Overview

This is the **main orchestration workflow** for pull request validation. It coordinates multiple reusable workflows to perform comprehensive checks on Terraform infrastructure code and general repository standards.

**Workflow File:** [.github/workflows/terraform_pull_request.yaml](../.github/workflows/terraform_pull_request.yaml)

### When It Runs

- Pull request opened, updated, reopened or synchronized

### When It Doesn't Run

- Pushes directly to `main` (no PR)
- PRs targeting other branches

## Required Permissions

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | write | Access repository code |
| `pull-requests` | write | Comment on PR with results |
| `id-token` | write | Potential OIDC authentication |

## Jobs

This workflow orchestrates three parallel jobs by calling reusable workflows:

### Job 1: Terraform Checks

Validates Terraform code quality and security.

```yaml
terraform_lint_and_validate:
  name: Terraform Checks
  uses: ./.github/workflows/terraform_checks.yaml
  secrets: inherit
  with:
    path: "terraform"
```

**What it does:**
- Runs Terraform format check
- Validates Terraform syntax
- Executes TFLint for best practices
- Performs Checkov security scanning

**Path:** Only checks the `terraform/` directory

**Details:** See [terraform_checks.md](terraform_checks.md)

### Job 2: General Checks

Performs code quality and security checks.

```yaml
general_checks:
  name: General Checks
  uses: ./.github/workflows/general_checks.yaml
  secrets: inherit
```

**What it does:**
- YAML linting across repository
- Secret detection with Gitleaks

**Path:** Checks entire repository (default `.`)

**Details:** See [general_checks.md](general_checks.md)

### Job 3: Unit Tests (Placeholder)

Reserved for future unit test implementation.

```yaml
# Unit tests should be added here.
```

**Status:** Not yet implemented

## Workflow Execution

### Parallel Execution

All jobs run **in parallel** for faster feedback:

```
Pull Request Created/Updated
         │
         ├─────────────────┬─────────────────┐
         │                 │                 │
    Terraform          General          Unit Tests
      Checks           Checks          (placeholder)
         │                 │                 │
         ├─ Format         ├─ YAML Lint     └─ (future)
         ├─ Validate       └─ Gitleaks
         ├─ TFLint
         └─ Checkov
         │
    All jobs complete
         │
    PR Status Updated
```

## Branch Protection Rules

Recommended branch protection settings for `main`:

**Navigate to:** Settings → Branches → Branch protection rules

### Required Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| Require pull request | ✅ Enabled | All changes via PR |
| Require approvals | 1-2 | Code review required |
| Require status checks | ✅ Enabled | All CI must pass |
| Status checks to require | Terraform Checks<br>General Checks | Both jobs must pass |
| Require branches up to date | ✅ Enabled | Prevent stale PRs |
| Require conversation resolution | ✅ Enabled | All comments addressed |
| Include administrators | ✅ Enabled | Enforce for everyone |

## Related Documentation

- [terraform_checks.md](terraform_checks.md) - Detailed Terraform validation
- [general_checks.md](general_checks.md) - Code quality checks
- [kt-02-making-infrastructure-changes.md](kt-02-making-infrastructure-changes.md) - Running these same checks locally before opening a PR
- [README.md](README.md) - Documentation home

## Additional Resources

- [GitHub Actions: Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions: Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Terraform CI/CD Best Practices](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
