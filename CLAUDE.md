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

## Git Workflow (Feature Development)

This workflow applies to all stack changes (ingestion, security, warehouse, etc.).

### Branch naming
```
feat/<TICKET-ID>-<short-description>    # new features
fix/<TICKET-ID>-<short-description>     # bug fixes
```
Example: `feat/R2EP2IC-139-add-tea-glue-crawler-dev`

### Step-by-step

**1. Create a feature branch**
```bash
git checkout -b feat/<TICKET-ID>-<short-description>
```

**2. Make your change**
- Inline policy changes → `terraform/security/locals.tf`
- Environment variable changes → `terraform/<stack>/variables/<env>.tfvars`
- If Checkov flags new actions in a plan scan → add skip to `.config/.checkov.yaml` with justification

**3. Run pre-commit locally before staging**
```bash
pre-commit run --all-files
```
- If `terraform_fmt` fails → it auto-fixes the file. Re-stage and run again.
- If `terraform_docs` fails → it auto-updates `README.md`. Re-stage and run again.
- It will pass on the second run.

**4. Stage and commit (Conventional Commits required)**
```bash
git add <changed-files>
git commit -m "feat(scope): short description

Longer explanation of why the change was made."
```
Valid types: `feat`, `fix`, `chore`, `docs`, `refactor`. The `commit-msg` hook rejects non-conforming messages.

**5. Push and open a PR**
```bash
git push -u origin <branch-name>
gh pr create --title "..." --body "..."
```

**6. Wait for the plan to finish before merging**
Two CI workflows fire on PR open:
- `terraform_pull_request.yaml` — fmt/validate/tflint/checkov gate (credential-free)
- `terraform_plan.yml` — runs `terraform plan` per environment, uploads `tfplan-<stack>-pr-<n>-<env>` artifact, posts plan diff to PR

**Wait for the plan comment to appear on the PR before merging.** Merging before the plan artifact is uploaded causes the apply to fail with "No plan artifact found" (race condition).

**7. Review the plan diff, then merge**
Confirm only the expected resource changes appear — no unintended drift. After merge to `main`, `terraform_apply.yml` downloads the reviewed plan artifact and applies it. The plan is never re-generated at apply time.

### Key rules
- **Never create AWS resources manually** if Terraform owns them — causes `InvalidPermission.Duplicate` or drift. Use `terraform import` if a resource already exists in AWS.
- **If an apply partially succeeds then fails** → the state has changed. The old plan artifact is now stale. Create a new PR with a trivial change to force a fresh plan.
- **Empty commits don't retrigger path-filtered workflows** — the workflow only fires when files under `terraform/<stack>/**` change. Use a comment tweak in a `.tf` or `.tfvars` file instead.
- **Checkov `#checkov:skip` comments on resources do not apply when scanning `tfplan.json` in CI** — add the check ID to `.config/.checkov.yaml` with a justification comment instead.
- **`*.tfvars` outside `variables/` subdirectories are gitignored** — never commit a tfvars file outside that path.

### Pre-flight checklist before merging
- [ ] Change is in the correct environment file (dev vs prod)
- [ ] `pre-commit run --all-files` passes locally
- [ ] Commit message follows Conventional Commits
- [ ] Plan comment has appeared on the PR
- [ ] Plan diff shows only the expected changes — no unintended resource changes

## AWS Account Overview

| Environment | Account ID | Purpose |
|---|---|---|
| `dev` | `784590287037` | Active development — broader write permissions, DROP allowed |
| `prod` | *(see prod.tfvars)* | Production — DataEngineer role is read-only, no DROP |
| `state` | `471624149663` | Terraform state storage — `region-20-tf-state` S3 bucket + KMS |

AWS SSO profile for local work: `dev-data-engineer`

```bash
aws sso login --profile dev-data-engineer
aws s3 ls --profile dev-data-engineer   # verify access
```

## Data Architecture

Three-layer medallion architecture on S3 + Glue Catalog:

| Layer | S3 Bucket | Glue Database | Description |
|---|---|---|---|
| Raw | `escr20-landing-zone-raw-<env>` | `escr20_raw` | Unprocessed files from external sources |
| Bronze | `escr20-bronze-<env>` | `escr20_bronze` | Ingested and lightly cleaned data |
| Silver | `escr20-silver-<env>` | `escr20_silver` | Curated and transformed data (dbt) |

**Data sources:**
- **Ascender** — CSV invoices (manually managed Glue table — OpenCSVSerDe, 70 fixed columns)
- **Connect20** — Parquet files (crawler-managed, auto-schema)
- **TEA** — CSV files from Texas Education Agency via Google Drive sync (101 distinct schemas)
- **Airbyte** — pulls from Oracle, MSSQL, Docebo, and other sources into Bronze

**Transforms:** dbt handles Bronze → Silver. Project: `r20_esc`. Run from `dbt/r20_esc/`.

## Gotchas & Known Issues

Things that have burned the team — read this before touching AWS or CI:

- **Never create AWS resources manually if Terraform owns them.** The next apply will fail with `InvalidPermission.Duplicate` or similar. If a resource already exists in AWS, import it first: `terraform import <address> <id>`.
- **Wait for the plan comment on the PR before merging.** The apply runs immediately on merge. If the plan artifact hasn't finished uploading, the apply fails with "No plan artifact found". This is a race condition — the plan comment appearing on the PR is your signal it's safe to merge.
- **Empty commits don't retrigger path-filtered workflows.** Each stack workflow only triggers when files under `terraform/<stack>/**` change. To retrigger, make a comment tweak in any `.tf` or `.tfvars` file in that stack.
- **`#checkov:skip` on a resource doesn't apply when CI scans `tfplan.json`.** Source-level skip comments are ignored during plan-file scanning. Add the check ID to `.config/.checkov.yaml` with a justification instead.
- **If an apply partially succeeds then fails**, the Terraform state has changed and the old plan artifact is stale. Terraform will reject it with "Saved plan is stale". Fix: open a new PR with any change to that stack to generate a fresh plan.
- **`terraform_docs` rewrites `README.md` on first pre-commit run.** This is expected. Re-stage the modified README and run `pre-commit run --all-files` again — it passes on the second run.
- **SSO reserved roles (`/aws-reserved/sso.amazonaws.com/`) are rejected by `PutDataLakeSettings`** — that's why `lakeformation_admin_arns = []` in dev. Lake Formation access is granted via manual `lakeformation:GetDataAccess` on the SSO permission sets instead.

## Onboarding — First-Time Setup

Run once per machine:

```bash
# 1 — trust mise and install pinned tools (terraform, trufflehog, pre-commit, uv)
mise trust && mise install

# 2 — install pre-commit hooks into the repo
mise run setup

# 3 — install tools not yet in mise.toml
mise use -g tflint@latest
mise use -g terraform-docs@latest
brew tap minamijoyo/tfupdate && brew install tfupdate

# 4 — verify all three are on PATH
which tflint && tflint --version
which terraform-docs && terraform-docs --version
which tfupdate && tfupdate --version

# 5 — configure AWS SSO profile for dev
aws configure sso --profile dev-data-engineer
# SSO start URL: https://d-9067ea424b.awsapps.com/start
# Region: us-east-1

# 6 — log in
aws sso login --profile dev-data-engineer
```

**Troubleshooting:** If `which <tool>` returns nothing after install, the binary isn't on PATH. For `tflint` and `terraform-docs`, prefer `mise use -g` over `brew` — mise manages the PATH automatically.

## Project & Team

- **Client:** ESC Region 20 (educational service center, San Antonio TX)
- **Caylent team:** Data Engineering squad
- **Ticket tracker:** R2EP2IC-* ticket format (e.g. `feat/R2EP2IC-139-add-tea-glue-crawler-dev`)
- **Prod protection:** `**/variables/prod.tfvars` requires prod-owners review before merge — never apply prod changes without a reviewed plan and approval

## Further Reading

- `docs/README.md` — workflow overview and pull-request flow diagrams
- `docs/deployment_with_artifacts.md` — full plan-artifact handoff walkthrough and new-stack creation guide
- `docs/build_and_push.md` — Docker/ECR build pipeline (for future container-based stacks)
- `docs/terraform_checks.md`, `docs/general_checks.md`, `docs/terraform_pull_request.md` — per-workflow reference
