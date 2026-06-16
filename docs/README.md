# Region 20 Infrastructure — Documentation

Welcome. This repository holds the **Infrastructure as Code (IaC)** for the Region 20 data platform on **Amazon Web Services (AWS)**. Everything here: networks, databases, storage, IAM roles, monitoring are defined as **Terraform** code (a tool that describes cloud resources in text files so they can be reviewed, versioned, and re-created reliably) and is deployed automatically by **GitHub Actions** (the CI/CD system built into GitHub that runs our build, test, and deploy steps).

> **What is CI/CD?** CI/CD stands for Continuous Integration / Continuous Delivery, the practice of automatically checking and deploying code changes. In this repo opening a pull request runs checks and produces a deployment plan, merging it applies that plan to AWS.

## Start here (new to the project?)

Read these in order. Each one builds on the previous, and together they take you from "what is this?" to "I can safely operate it."

1. **[Concepts & Glossary](concepts-glossary.md)** — Plain-language definitions of every term and AWS service used across these docs (Terraform, OIDC, IAM, workspaces, state, and more). Keep it open as a reference while you read the rest.
2. **[01 — Infrastructure Overview](kt-01-infrastructure-overview.md)** — The big picture: what the platform is made of, how the repository is laid out, and how the AWS accounts fit together.
3. **[02 — Making Infrastructure Changes](kt-02-making-infrastructure-changes.md)** — How to safely edit Terraform code on your own machine, including the local checks that run before you ever push.
4. **[03 — Deployment Guide](kt-03-deployment-guide.md)** — What happens after you open a pull request: how a change is planned, reviewed, and applied to AWS automatically.
5. **[04 — Operations Runbook](kt-04-operations-runbook.md)** — Day-to-day operational procedures, including the bootstrap lifecycle of the foundational `base` stack.
6. **[05 — Troubleshooting Guide](kt-05-troubleshooting-guide.md)** — Symptom-driven fixes for the most common failures you will encounter in CI/CD and Terraform.
7. **[06 — dbt Build-and-Deploy Pipeline](kt-06-dbt-build-and-deploy.md)** — How the dbt container image is built, scanned, shipped to dev automatically, and promoted to prod with a release tag. Read this once you understand the Terraform pipeline (03–05); it covers application/container deployment, not infrastructure.
8. **[07 — Airbyte Self-Hosted Deployment](kt-07-airbyte-deployment.md)** — How self-hosted Airbyte OSS runs on AWS: the Graviton EC2 server and its Auto Scaling Group, the public ALB and DNS/TLS, the external state in RDS/S3/Secrets Manager/SSM, the boot sequence, and how to reach and debug the instance.

## Knowledge-transfer documents

The documents that make up the guided learning path above. Start at the top if you are new. Items 01–05 cover the Terraform infrastructure pipeline; item 06 covers the dbt container deployment pipeline that runs on top of it, and item 07 covers the self-hosted Airbyte deployment.

| Document | What it covers |
|----------|----------------|
| [Concepts & Glossary](concepts-glossary.md) | Definitions of all terms and AWS services referenced in these docs. |
| [01 — Infrastructure Overview](kt-01-infrastructure-overview.md) | Platform components, repository structure, and AWS account topology. |
| [02 — Making Infrastructure Changes](kt-02-making-infrastructure-changes.md) | Editing Terraform locally; pre-commit checks and how to run them. |
| [03 — Deployment Guide](kt-03-deployment-guide.md) | The pull-request plan/apply pipeline and the OIDC authentication flow. |
| [04 — Operations Runbook](kt-04-operations-runbook.md) | Operational procedures and the `base` stack bootstrap lifecycle. |
| [05 — Troubleshooting Guide](kt-05-troubleshooting-guide.md) | Common errors and their resolutions. |
| [06 — dbt Build-and-Deploy Pipeline](kt-06-dbt-build-and-deploy.md) | Building, scanning, and pushing the dbt container to ECR; automatic dev deploys on PR and tag-gated prod promotion. |
| [07 — Airbyte Self-Hosted Deployment](kt-07-airbyte-deployment.md) | The self-hosted Airbyte OSS deployment: Graviton EC2 + ASG, public ALB/DNS/TLS, external state (RDS/S3/Secrets/SSM), the user-data boot sequence, SSM access, and kubectl/abctl debugging. |

## Reference (deep dive)

These are the authoritative, detailed references behind the knowledge-transfer documents. Read them when you need the full mechanics rather than the guided introduction. Each one now opens with a short "In plain terms" summary and links back here.

| Document | What it covers |
|----------|----------------|
| [Deployment with Artifacts](deployment_with_artifacts.md) | The full plan-artifact handoff: how a reviewed plan from a PR becomes the exact apply on merge, plus how to add a new stack or environment. |
| [OIDC Role Chain](oidc_role_chain.md) | The hub-and-spoke authentication model: GitHub OIDC → central CI role → per-account execution role, with trust policies and account topology. |
| [Terraform Pull Request Workflow](terraform_pull_request.md) | The main PR validation workflow that gates every change. |
| [Terraform Checks](terraform_checks.md) | The reusable credential-free workflow: format, validate, TFLint, and Checkov security scanning. |
| [General Checks](general_checks.md) | The reusable workflow for YAML linting and secret detection (Gitleaks). |

## Supporting / architecture docs

Topic-specific design and operational references. Read these when working on the relevant area.

| Document | What it covers |
|----------|----------------|
| [dbt / Airbyte Compute Options](dbt_airbyte_compute_options.md) | Compute trade-offs for running dbt transformations and Airbyte connectors. |
| [Monitoring](monitoring.md) | The monitoring stack: alarms, metrics, and observability for the platform. |
| [S3 Data Lake Structure — Cloud](s3-data-lake-structure-cloud.md) | The cloud (AWS-native) layout of the S3 data lake. |
| [S3 Data Lake Structure — OSS](s3-data-lake-structure-oss.md) | The open-source-tooling layout of the S3 data lake. |

## Workflow overview

The CI/CD pipeline is built from **GitHub Actions workflows** (YAML files under `.github/workflows/`). There are two tiers: small **reusable** workflows that do one job, and **orchestrator** workflows (one per stack) that wire them together. The table below links each workflow to its source file and, where one exists, to its reference doc.

> **What is a "stack"?** A stack is one self-contained Terraform configuration directory under `terraform/` (for example `terraform/networking/`). Each stack has its own orchestrator workflow that deploys only that stack.

| Workflow | Type | Trigger | Purpose | Reference doc |
|----------|------|---------|---------|---------------|
| [terraform_pull_request.yaml](../.github/workflows/terraform_pull_request.yaml) | Orchestrator (PR gate) | Pull request | Runs the credential-free checks on every PR touching Terraform | [terraform_pull_request.md](terraform_pull_request.md) |
| [terraform_checks.yaml](../.github/workflows/terraform_checks.yaml) | Reusable | Called by the PR gate | Terraform format, validate, TFLint, Checkov | [terraform_checks.md](terraform_checks.md) |
| [general_checks.yaml](../.github/workflows/general_checks.yaml) | Reusable | Called by the PR gate | YAML lint and secret detection (Gitleaks) | [general_checks.md](general_checks.md) |
| [terraform_plan.yml](../.github/workflows/terraform_plan.yml) | Reusable | Called by orchestrators | Generate and upload a reviewed Terraform plan artifact | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_apply.yml](../.github/workflows/terraform_apply.yml) | Reusable | Called by orchestrators | Apply the exact plan that was reviewed on the PR | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_base.yml](../.github/workflows/terraform_base.yml) | Orchestrator | Push / PR | Deploy the `base` stack (Terraform state backend + GitHub OIDC) | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_audit.yml](../.github/workflows/terraform_audit.yml) | Orchestrator | Push / PR | Deploy the `audit` account resources | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_security.yml](../.github/workflows/terraform_security.yml) | Orchestrator | Push / PR | Deploy the `security` stack (IAM Identity Center) | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_networking.yml](../.github/workflows/terraform_networking.yml) | Orchestrator | Push / PR | Deploy networking resources (VPC, subnets, routing) | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_service_account.yml](../.github/workflows/terraform_service_account.yml) | Orchestrator | Push / PR | Deploy the `service-account` stack | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_ingestion.yml](../.github/workflows/terraform_ingestion.yml) | Orchestrator | Push / PR | Deploy the `ingestion` stack | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_warehouse.yml](../.github/workflows/terraform_warehouse.yml) | Orchestrator | Push / PR | Deploy the `warehouse` stack | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_transformations.yml](../.github/workflows/terraform_transformations.yml) | Orchestrator | Push / PR | Deploy the `transformations` stack | [deployment_with_artifacts.md](deployment_with_artifacts.md) |
| [terraform_monitoring.yml](../.github/workflows/terraform_monitoring.yml) | Orchestrator | Push / PR | Deploy the `monitoring` stack | [monitoring.md](monitoring.md) |
| [build_dbt.yml](../.github/workflows/build_dbt.yml) | Orchestrator | PR (dbt/**) / tag (dbt-v*) | Build + scan + push the dbt image and deploy to dev on PR; promote to prod on a release tag | [kt-06-dbt-build-and-deploy.md](kt-06-dbt-build-and-deploy.md) |
| [build_and_push.yml](../.github/workflows/build_and_push.yml) | Reusable | Called by `build_dbt.yml` | Generic Docker build/scan/push to ECR | [kt-06-dbt-build-and-deploy.md](kt-06-dbt-build-and-deploy.md) |

> **Note:** The `airbyte-connectors` stack has **no workflow**, it is applied manually. There is also a template at [.github/workflows/templates/terraform_stack.yml](../.github/workflows/templates/terraform_stack.yml) used as the starting point when adding a new stack.

> **A note on GitHub variables:** This repository uses a **single** central CI role for every environment (the GitHub variable `AWS_ROLE_ARN`). See the [OIDC Role Chain](oidc_role_chain.md) for the authentication model actually in use.

## Workflow diagrams

### Pull request flow

When a pull request is opened, two sets of credential-free checks run in parallel. The PR can merge only after both pass.

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

### Deployment flow

A separate per-stack workflow generates a Terraform **plan** on the PR, uploads it as an artifact, and — once the PR merges to `main` — applies that exact saved plan. The plan is never regenerated at apply time, so what you reviewed is precisely what gets deployed.

```
Pull Request
         │
    Terraform Plan
         │
    ├─ terraform init
    ├─ terraform validate
    ├─ Checkov security
    └─ Upload plan artifact
         │
    Review & Merge
         │
    Terraform Apply
         │
    ├─ Download reviewed plan
    ├─ Apply the exact plan
    └─ Deploy to AWS
```

For the full mechanics of how the reviewed plan becomes the apply, see [Deployment with Artifacts](deployment_with_artifacts.md).

## Additional resources

### GitHub Actions

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Action Marketplace](https://github.com/marketplace?type=actions)

### Tools

- [Terraform](https://developer.hashicorp.com/terraform/docs)
- [TFLint](https://github.com/terraform-linters/tflint)
- [Checkov](https://www.checkov.io/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [yamllint](https://yamllint.readthedocs.io/)

### AWS

- [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
