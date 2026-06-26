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

## Post-Deployment

1. **Get admin credentials:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id "<project>-<env>/airbyte-admin-creds" \
     --query SecretString --output text
   ```

2. **Access the console** at the `airbyte_url` output or `alb_dns_name`

3. **Attach connector permissions** to `instance_role_arn` for the data sources Airbyte needs to reach

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
