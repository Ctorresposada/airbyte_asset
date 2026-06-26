# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

**Airbyte Asset** — a reusable Terraform module that deploys a fully functional self-hosted Airbyte console into any AWS account. Built by the Caylent Center of Excellence for Data Modernization.

This is **not** a customer-specific deployment. It is a portable asset: provide a VPC, subnets, and optionally a domain name, and it deploys a production-ready Airbyte console with all supporting infrastructure.

## Tooling & Environment

- **mise** orchestrates pinned tool versions (`mise.toml`): Terraform `1.11.3`, trufflehog, pre-commit. Run `mise trust` once per machine, then `mise install`.
- No Python runtime is required — this is a pure Terraform project.
- Note: `mise.toml` pins Terraform `1.11.3` for local use, but CI workflows hard-default to `1.11.3`. Bumping the version requires updating both.

## Common Commands

```bash
mise run setup                 # install pre-commit hooks
mise run trufflehog-scan       # secret scan (since HEAD)
pre-commit run --all-files     # run every hook (terraform_fmt, tflint, terraform_docs, tfupdate, checkov, yamllint, trufflehog, conventional-pre-commit)
```

Terraform validation:

```bash
cd terraform
terraform fmt -check -recursive
terraform init -upgrade -input=false -lock=false -reconfigure -backend=false
terraform validate
tflint --config "$(git rev-parse --show-toplevel)/.config/.tflint.hcl" --recursive
checkov --config-file ./.config/.checkov.yaml -d .
```

Commits **must** be Conventional Commits — `conventional-pre-commit` runs as a `commit-msg` hook and will reject non-conforming messages.

## Repository Architecture

### Layout

```
terraform/
├── main.tf              # Root module — instantiates the airbyte module
├── variables.tf         # All deployment inputs (VPC, subnets, domain, sizing)
├── outputs.tf           # Key outputs (URL, secrets, endpoints)
├── providers.tf         # AWS provider with default tags
├── terraform.tf         # Required versions + backend config
├── variables/           # Per-environment tfvars files
│   └── dev.tfvars       # Example dev configuration
└── modules/
    └── airbyte/         # The core self-hosted Airbyte module
        ├── main.tf      # KMS, IAM, SGs, RDS, S3, SSM, ALB, ASG, ACM, Route53
        ├── variables.tf # Module inputs
        ├── outputs.tf   # Module outputs
        ├── versions.tf  # Provider constraints
        └── templates/
            ├── user-data.sh.tpl         # EC2 bootstrap (Docker, abctl, Airbyte install)
            └── airbyte-values.yaml.tpl  # Helm values for Airbyte chart
```

### What the module deploys

- **EC2 ASG** (singleton) with abctl (kind-in-Docker) running Airbyte
- **RDS PostgreSQL 16** for Airbyte config DB + Temporal workflow engine
- **ALB** with HTTPS (TLS 1.3) + HTTP→HTTPS redirect
- **ACM Certificate** with DNS validation (auto-created when domain_name is set)
- **Route53 A record** pointing to the ALB
- **S3 bucket** for Airbyte logs, state, and workload output
- **KMS CMK** encrypting EBS, RDS, S3, Secrets Manager, CloudWatch, SSM
- **Secrets Manager** for RDS credentials + Airbyte admin credentials
- **CloudWatch Log Group** for Airbyte system logs
- **Security Groups** for ALB, EC2, and RDS (least-privilege)
- **IAM** instance profile with scoped permissions (S3, SSM, Secrets Manager, KMS)
- **SSM Parameter** for Helm values delivery to EC2 at boot

### Key inputs (root module)

| Variable | Required | Description |
|---|---|---|
| `project_name` | Yes | Prefix for all resources |
| `environment` | Yes | e.g. `dev`, `prod` |
| `vpc_id` | Yes | Existing VPC |
| `private_subnet_ids` | Yes | For EC2 + RDS (min 2 AZs) |
| `public_subnet_ids` | Yes (if ALB) | For the ALB |
| `domain_name` | No | FQDN for Airbyte (auto-provisions cert) |
| `route53_zone_id` | No | For DNS record + cert validation |

## Conventions

- Terraform naming: `snake_case` for all declarations (enforced by `.config/.tflint.hcl`)
- Use `#` for Terraform comments, not `//`
- `terraform-docs` auto-injects `BEGIN_TF_DOCS`/`END_TF_DOCS` blocks into README.md on commit
- Checkov skips in `.config/.checkov.yaml` — per-resource skips use `#checkov:skip=<id>: <reason>` inline
- `*.tfvars` files are gitignored globally; the exception is `terraform/variables/*.tfvars`

## Git Workflow

### Branch naming
```
feat/<short-description>    # new features
fix/<short-description>     # bug fixes
```

### Step-by-step

1. `git checkout -b feat/short-description`
2. Make changes
3. `pre-commit run --all-files` (re-stage if terraform_fmt or terraform_docs auto-fix)
4. `git commit -m "feat(airbyte): short description"`
5. `git push -u origin <branch>` → open PR

### Pre-flight checklist
- [ ] `pre-commit run --all-files` passes locally
- [ ] Commit message follows Conventional Commits

## Onboarding

```bash
mise trust && mise install
mise run setup
mise use -g tflint@latest
mise use -g terraform-docs@latest
brew tap minamijoyo/tfupdate && brew install tfupdate
```
