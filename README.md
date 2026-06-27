# Airbyte Asset

A reusable Terraform module that deploys a fully functional **self-hosted Airbyte** console into any AWS account. Built by the **Caylent Center of Excellence for Data Modernization**.

## What It Deploys

| Component | Description |
|---|---|
| **EC2 Auto Scaling Group** | Singleton instance running Airbyte via [abctl](https://github.com/airbytehq/abctl) (kind-in-Docker) |
| **Application Load Balancer** | HTTPS (TLS 1.3) with HTTP→HTTPS redirect |
| **ACM Certificate** | Auto-provisioned and DNS-validated (when domain is provided) |
| **Route53 DNS Record** | A record pointing to the ALB |
| **RDS PostgreSQL 16** | Airbyte config DB + Temporal workflow engine |
| **S3 Bucket** | Airbyte logs, state payloads, and workload output |
| **KMS CMK** | Encrypts EBS, RDS, S3, Secrets Manager, CloudWatch, SSM |
| **Secrets Manager** | RDS credentials + Airbyte admin credentials (auto-populated at boot) |
| **CloudWatch Logs** | Airbyte system and pod logs |
| **Security Groups** | Least-privilege rules for ALB, EC2, and RDS |
| **IAM Instance Profile** | Scoped permissions for S3, SSM, Secrets Manager, KMS |

## Prerequisites

- An AWS account with an existing **VPC** containing public and private subnets
- (Optional) A **Route53 hosted zone** for custom domain + automatic certificate provisioning
- Terraform >= 1.11.0

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Ctorresposada/airbyte_asset.git
cd airbyte_asset/terraform

# 2. Copy and edit the example tfvars
cp variables/dev.tfvars variables/myenv.tfvars
# Edit myenv.tfvars with your VPC, subnet IDs, and domain

# 3. Initialize and plan
terraform init
terraform workspace new myenv
terraform plan -var-file=variables/myenv.tfvars

# 4. Apply
terraform apply -var-file=variables/myenv.tfvars
```

## Required Inputs

| Variable | Type | Description |
|---|---|---|
| `project_name` | `string` | Name prefix for all resources (e.g. `acme-airbyte`) |
| `environment` | `string` | Deployment environment (`dev`, `staging`, `prod`) |
| `vpc_id` | `string` | ID of the existing VPC |
| `private_subnet_ids` | `list(string)` | Private subnets for EC2 + RDS (min 2 AZs) |
| `public_subnet_ids` | `list(string)` | Public subnets for the ALB |

## Optional Inputs

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `us-east-1` | AWS region |
| `domain_name` | `string` | `""` | FQDN for Airbyte (e.g. `airbyte.example.com`) |
| `route53_zone_id` | `string` | `""` | Route53 zone for DNS + cert validation |
| `alb_certificate_arn` | `string` | `""` | Existing ACM cert ARN (skips auto-creation) |
| `instance_type` | `string` | `m6a.xlarge` | EC2 instance type (min 4 vCPU / 16 GB) |
| `ami_architecture` | `string` | `arm64` | `arm64` for Graviton, `x86_64` for Intel/AMD |
| `ebs_volume_size` | `number` | `50` | Root volume size in GB |
| `rds_instance_class` | `string` | `db.t3.micro` | RDS instance class |
| `rds_multi_az` | `bool` | `false` | Enable Multi-AZ (recommended for prod) |
| `rds_deletion_protection` | `bool` | `false` | Enable deletion protection (recommended for prod) |
| `log_retention_days` | `number` | `90` | CloudWatch log retention |
| `tags` | `map(string)` | `{}` | Additional tags for all resources |

## Outputs

| Output | Description |
|---|---|
| `airbyte_url` | HTTPS URL for the Airbyte console |
| `alb_dns_name` | ALB DNS name (use if no custom domain) |
| `airbyte_admin_secret_arn` | Secrets Manager ARN with admin credentials |
| `rds_endpoint` | RDS PostgreSQL endpoint |
| `instance_role_arn` | IAM role to attach additional connector policies |
| `kms_key_arn` | KMS key encrypting all resources |

## S3 Bucket

The module creates an S3 bucket (`<project_name>-<environment>`) used by Airbyte as its workload storage backend, replacing the default local PVC storage inside the kind cluster:

| Prefix | Purpose | When it gets populated |
|---|---|---|
| `logs/` | Connector sync logs | When a sync job runs |
| `state/` | State payloads (incremental sync cursors) | When a sync completes and saves its checkpoint |
| `workload-output/` | Sync output data (temporary staging) | During active syncs |

The bucket is empty after initial deployment — objects appear once you create connections and run syncs.

## Post-Deployment

1. **Get admin credentials:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id "<project>-<env>/airbyte-admin-creds" \
     --query SecretString --output text
   ```

2. **Access the console** at the `airbyte_url` output or `alb_dns_name`

3. **Attach connector permissions** to `instance_role_arn` for the data sources Airbyte needs to reach

## Repository Structure

```
terraform/
├── main.tf                              # Root module — deploys Airbyte infra (43 resources)
├── variables.tf                         # All deployment inputs
├── outputs.tf                           # Key outputs
├── providers.tf                         # AWS provider
├── terraform.tf                         # Version constraints
├── variables/
│   └── dev.tfvars                       # Example environment config
├── modules/
│   └── airbyte/                         # Core self-hosted Airbyte module
│       ├── main.tf                      # KMS, IAM, SGs, RDS, S3, ALB, ASG, ACM, Route53
│       ├── variables.tf / outputs.tf
│       ├── versions.tf
│       └── templates/
│           ├── user-data.sh.tpl         # EC2 bootstrap (Docker, abctl, Airbyte)
│           └── airbyte-values.yaml.tpl  # Helm values for Airbyte chart
├── connectors/                          # Optional: generic connector definitions
│   ├── sources.tf                       # Oracle + SQL Server sources
│   ├── destinations.tf                  # S3 Data Lake destination
│   ├── variables.tf / outputs.tf
│   └── variables/dev.tfvars
└── examples/
    └── oracle-sqlserver-s3/             # Working example: end-to-end deployment
        ├── main.tf                      # Sources, destination, connections
        ├── variables.tf / outputs.tf
        └── variables/dev.tfvars
```

Each directory is an **independent Terraform root module** with its own state. Running `terraform apply` in one does not affect the others.

## Examples

### Oracle + SQL Server → S3 Data Lake

A complete working example at `terraform/examples/oracle-sqlserver-s3/` that creates:

- **Oracle source** — community connector with service_name connection
- **SQL Server source** — with Trust Server Certificate SSL
- **S3 Data Lake destination** — Iceberg format with AWS Glue Catalog
- **Two connections** — Oracle → S3 (prefix: `oracle_`) and SQL Server → S3 (prefix: `sqlserver_`), both Full Refresh Overwrite, manual schedule

#### How it works

- Source database **passwords are fetched from AWS Secrets Manager** at plan time via ARN — never hardcoded in tfvars
- **Airbyte API authentication** uses a bearer token obtained from the self-hosted token endpoint (`/api/v1/applications/token`) with client credentials from the K8s secret `airbyte-auth-secrets`
- The [Airbyte Terraform provider](https://registry.terraform.io/providers/airbytehq/airbyte/latest) (v1.x) uses generic `airbyte_source` / `airbyte_destination` resources with inline JSON configuration

#### Usage

```bash
cd terraform/examples/oracle-sqlserver-s3

# 1. Copy and edit the tfvars
cp variables/dev.tfvars variables/myenv.tfvars
# Fill in: Airbyte URL, client credentials, workspace ID,
#          source DB endpoints, Secrets Manager ARNs,
#          S3 bucket details, Glue catalog config

# 2. Init and apply
terraform init
terraform apply -var-file=variables/myenv.tfvars
```

#### Required inputs

| Variable | Description |
|---|---|
| `airbyte_server_url` | Airbyte API URL (e.g. `https://airbyte.example.com/api/public/v1/`) |
| `airbyte_token_url` | Token endpoint (e.g. `https://airbyte.example.com/api/v1/applications/token`) |
| `airbyte_client_id` | From K8s secret `airbyte-auth-secrets` → `instance-admin-client-id` |
| `airbyte_client_secret` | From K8s secret `airbyte-auth-secrets` → `instance-admin-client-secret` |
| `workspace_id` | From the Airbyte UI URL (Settings > General) |
| `oracle_host`, `oracle_service_name` | Oracle RDS endpoint and service name |
| `oracle_password_secret_arn` | Secrets Manager ARN for Oracle password |
| `mssql_host`, `mssql_database` | SQL Server RDS endpoint and database |
| `mssql_password_secret_arn` | Secrets Manager ARN for SQL Server password |
| `s3_bucket_name`, `s3_bucket_region` | Target S3 bucket for the data lake |
| `s3_access_key_id`, `s3_secret_access_key` | AWS credentials for S3 writes |
| `glue_database`, `glue_account_id` | Glue Catalog database and account |

#### Networking note

The Airbyte EC2 security group only allows HTTPS/HTTP egress by default. To reach external databases, you must add **egress rules** for the required ports (e.g. 1521 for Oracle, 1433 for SQL Server). The target database security groups must also allow **inbound** from the Airbyte NAT gateway's public IP.

## Security Scanning (Checkov)

This project uses [Checkov](https://www.checkov.io/) to scan Terraform for security misconfigurations. The configuration at `.config/.checkov.yaml` includes **18 intentional exceptions**, grouped by risk level:

### Low risk — Terraform framework quirks

| Check | What it wants | Why we skip |
|---|---|---|
| `CKV_TF_1` | Pin module sources to commit hash | We use a local module, not a remote one |
| `CKV_TF_3` | State file locking | Fails with `-backend-config` flag; we use local state |

### Low risk — already handled differently

| Check | What it wants | Why we skip |
|---|---|---|
| `CKV_AWS_109` | Restrict `Resource:*` in KMS policy | `*` in a KMS key policy means "this key" — AWS-recommended pattern |
| `CKV_AWS_111` | Same as above for `kms:*` actions | Same reason |
| `CKV_AWS_158` | CMK on CloudWatch logs | We DO use CMK — checkov can't resolve it through the count index |
| `CKV_AWS_341` | IMDS hop limit = 1 | Hop limit > 1 required because Docker/kind adds network hops |
| `CKV2_AWS_71` | No wildcard certs | We don't use wildcards currently; skip is for deployment flexibility |
| `CKV2_AWS_62` | S3 event notifications | Not needed for a logs bucket |

### Medium risk — intentional trade-offs

| Check | What it wants | Why we skip |
|---|---|---|
| `CKV_AWS_157` | Multi-AZ RDS | Configurable via `rds_multi_az` variable — off by default for cost |
| `CKV_AWS_293` | RDS deletion protection | Configurable via `rds_deletion_protection` variable — off for dev |
| `CKV_AWS_150` | ALB deletion protection | Intentionally off for teardown flexibility |
| `CKV_AWS_91` | ALB access logging | Would need a dedicated S3 bucket — deferred; CloudTrail covers audit |
| `CKV_AWS_18` | S3 access logging | Same — CloudTrail covers the audit trail |
| `CKV_AWS_144` | S3 cross-region replication | Not needed for Airbyte logs/artifacts |
| `CKV2_AWS_57` | Secrets Manager auto-rotation | Would require a Lambda rotator + coordinated Airbyte restart |

### Higher risk — architectural constraints

| Check | What it wants | Why we skip |
|---|---|---|
| `CKV_AWS_161` | IAM auth for RDS | Airbyte does not support IAM authentication for its internal PostgreSQL |
| `CKV2_AWS_30` | RDS query logging | Internal metadata DB — excessive noise with no security value |
| `CKV2_AWS_28` | WAF on ALB | Cost not justified for an internal data-engineering tool |

## Development

```bash
# Install tools
mise trust && mise install
mise run setup
mise use -g tflint@latest terraform-docs@latest
brew tap minamijoyo/tfupdate && brew install tfupdate

# Run all checks
pre-commit run --all-files
```

## License

Proprietary — Caylent, Inc.
