# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tooling & Environment

- **mise** orchestrates pinned tool versions (`mise.toml`): Terraform `1.14.3`, trufflehog, pre-commit, uv. Run `mise trust` once per machine, then `mise install` to materialize the versions.
- **uv** manages the Python environment (`pyproject.toml`, requires Python `>=3.12`). The Python package itself (`nd_predictive_ordering`) is currently a stub — Python is here primarily for tooling (ruff) and future Lambda code.
- Note: `mise.toml` pins Terraform `1.14.3` for local use, but every CI workflow (`terraform_plan.yml`, `terraform_apply.yml`, `terraform_checks.yaml`) hard-defaults to `1.11.3`. Bumping the Terraform version requires updating both.

## Common Commands

```bash
mise run setup                 # uv sync + pre-commit install
mise run lint                  # ruff check via uv
mise run trufflehog-scan       # secret scan (since HEAD)
uvx ruff check . --fix         # auto-fix lint issues
pre-commit run --all-files     # run every hook (terraform_fmt, tflint, terraform_docs, tfupdate, checkov, yamllint, trufflehog, ruff, conventional-pre-commit)
```

Terraform from a stack directory (e.g., `terraform/base/`):

```bash
terraform fmt -check -recursive
terraform init -upgrade -input=false -lock=false -reconfigure -backend=false   # offline validation (matches CI)
terraform validate
tflint --config "$(git rev-parse --show-toplevel)/.config/.tflint.hcl" --recursive
checkov --config-file ./.config/.checkov.yaml -d .
```

Commits **must** be Conventional Commits — `conventional-pre-commit` runs as a `commit-msg` hook and will reject non-conforming messages.

## Repository Architecture

### Stack layout

```
terraform/
├── base/                      # Bootstrap stack: TF state backend + GitHub OIDC IAM role
│   ├── state.tf               # state-management module call (creates S3+KMS for TF state)
│   ├── oidc.tf                # oidc-provider module call (GitHub Actions → AWS role)
│   ├── variables.tf           # environment, aws_region, team, company_name
│   └── variables/             # one tfvars file per env — filename == env name
│       └── shared.tfvars
└── modules/
    ├── state-management/      # S3 bucket + KMS key + IAM policy for remote state
    └── oidc-provider/         # IAM OIDC provider + assume-role policy for github_repositories
```

**Bootstrap order matters.** `terraform/base/state.tf` intentionally has its `backend "s3"` block commented out. First apply happens locally with local state (creating the S3 bucket + KMS key via the `state-management` module), then you uncomment the backend block and `terraform init -migrate-state`. The same dance must be reversed (comment block, migrate state back to local) before destroying.

### Adding a new stack

A stack is any directory under `terraform/` with a `variables/` subdirectory of `<env>.tfvars` files. To create one:

1. Make `terraform/<stack-name>/` with `main.tf`, `variables.tf`, `providers.tf`, `terraform.tf`, `outputs.tf`, and a `variables/<env>.tfvars` per target environment.
2. Copy `.github/workflows/templates/terraform_stack.yml` to `.github/workflows/terraform_<stack-name>.yml` and substitute `${STACK_NAME}`.
3. Ensure GitHub repo variables exist for every env: `AWS_ROLE_ARN_<env>`, `STATE_BUCKET_<env>`, `STATE_KMS_KEY_ID_<env>`.

### CI architecture

Two-tier workflow design:

- **Reusable workflows** (`workflow_call`): `terraform_plan.yml`, `terraform_apply.yml`, `terraform_checks.yaml`, `general_checks.yaml`, `build_and_push.yml`.
- **Per-stack orchestrators**: `terraform_base.yml` (and any future `terraform_<stack>.yml`) trigger on push/PR to paths under their stack, dynamically build an environment matrix by listing `variables/*.tfvars`, then fan out to the reusable plan/apply workflows.
- **Repo-wide gate**: `terraform_pull_request.yaml` runs `terraform_checks.yaml` (fmt/validate/tflint/checkov) + `general_checks.yaml` (yamllint/gitleaks) on any PR touching `terraform/**`, `.github/workflows/terraform_checks.yaml`, or `.config/**` — these are credential-free and gate every PR.

### Plan-apply artifact handoff

Plans are **never re-generated at apply time**. `terraform_plan.yml` runs on PR, uploads a `tfplan-<stack>-pr-<n>-<env>` artifact (containing `tfplan`, `tfplan.txt`, `tfplan.json`, `deployment_id.txt`), and registers a `pending` GitHub Deployment. On merge to `main`, `terraform_apply.yml` resolves the PR number from the merge commit, finds the corresponding workflow run by artifact name (falling back to head SHA), downloads `tfplan`, and applies it. If the artifact cannot be located the job fails — apply is never allowed without a reviewed plan.

### Workspaces == environments

Both plan and apply call `terraform workspace new <env> 2>/dev/null || terraform workspace select <env>`. The env name is the basename of the tfvars file. A single state bucket holds all workspaces for a stack (keyed via `STATE_BUCKET_<env>` GitHub vars).

### Auth model

All AWS access from CI uses GitHub OIDC — no long-lived keys anywhere. The `terraform/base` stack is what *creates* the OIDC provider and the assumable role (currently with `AdministratorAccess` — see `terraform/base/oidc.tf`). After base is bootstrapped, every other workflow assumes `vars.AWS_ROLE_ARN_<env>` via `aws-actions/configure-aws-credentials`.

### CODEOWNERS

`**/variables/prod.tfvars` requires `@your-org/prod-owners` review (placeholder org — update before going live). Default owner is `@your-org/engineering`.

## Conventions

- Terraform naming is enforced by `.config/.tflint.hcl`: `snake_case` for variables, locals, outputs, resources, modules, data. `required_providers` and `required_version` are mandatory; all outputs and variables must have descriptions; all variables must be typed.
- Use `#` for Terraform comments, not `//` (enforced).
- `terraform-docs` auto-injects `BEGIN_TF_DOCS`/`END_TF_DOCS` blocks into each module/stack `README.md` on commit — don't hand-edit between those markers.
- Checkov skips in `.config/.checkov.yaml`: `CKV_TF_1` (commit-hash module sources), `CKV_TF_3` (state locking — fails with `-backend-config` flag), `CKV_AWS_355` (wildcard IAM resources). Per-resource skips use `#checkov:skip=<id>: <reason>` inline (see `terraform/base/oidc.tf`).
- `.gitignore` excludes `*.tfvars` globally — the committed env-specific tfvars under `terraform/*/variables/` are the exception, added explicitly. Never commit a `*.tfvars` outside a `variables/` subdirectory.

## Further Reading

- `docs/README.md` — workflow overview and pull-request flow diagrams
- `docs/deployment_with_artifacts.md` — full plan-artifact handoff walkthrough and new-stack creation guide
- `docs/build_and_push.md` — Docker/ECR build pipeline (for future container-based stacks)
- `docs/terraform_checks.md`, `docs/general_checks.md`, `docs/terraform_pull_request.md` — per-workflow reference
