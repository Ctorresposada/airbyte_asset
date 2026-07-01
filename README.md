# Airbyte Asset

A reusable Terraform module that deploys a fully functional **self-hosted Airbyte** console into any AWS account. Built by the **Caylent Center of Excellence for Data Modernization**.

## Deployment Variants

Two variants are available, selected by `deployment_type` in your tfvars:

| Variant | `deployment_type` | Approx. cost | Best for |
|---|---|---|---|
| **EC2** (default) | `"ec2"` | ~$150/mo | Simple, low-overhead deployments |
| **EKS** | `"eks"` | ~$300–500/mo | HA, Kubernetes-native environments |

Both variants share the same inputs and outputs. Switch between them by changing a single variable — no module restructuring required.

## What It Deploys

### EC2 variant (default)

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

### EKS variant

| Component | Description |
|---|---|
| **EKS Cluster** | Managed Kubernetes with public API endpoint (restrict with `public_access_cidrs` for prod) |
| **Managed Node Group** | ON_DEMAND m6a.xlarge × 2 (configurable), encrypted EBS, IMDSv2 |
| **EKS Add-ons** | vpc-cni, coredns, kube-proxy, ebs-csi (versions resolved dynamically) |
| **AWS Load Balancer Controller** | Provisions the ALB from the Airbyte Ingress annotation |
| **ExternalDNS** | Automatically manages the Route53 A record from the Ingress |
| **Airbyte Helm release** | Official chart, IRSA auth, external RDS + S3 backend |
| **ACM Certificate** | Auto-provisioned and DNS-validated (when domain is provided) |
| **RDS PostgreSQL 16** | Airbyte config DB + Temporal workflow engine |
| **S3 Bucket** | Airbyte logs, state payloads, and workload output |
| **KMS CMK** | Encrypts EBS, RDS, S3, Secrets Manager, CloudWatch |
| **Secrets Manager** | RDS credentials + Airbyte admin credentials placeholder |
| **CloudWatch Logs** | Airbyte system logs |
| **IRSA Roles** | Scoped roles for Airbyte pods, EBS CSI, ALB controller, ExternalDNS |

## Prerequisites

- An AWS account with an existing **VPC** containing public and private subnets
- Terraform >= 1.11.0
- (Optional) A Route53 hosted zone — required for custom domain + automatic certificate provisioning (see [DNS Setup](#dns-setup) below)

## DNS Setup

This section only applies if you want a custom domain (e.g. `airbyte.example.com`) with HTTPS. If you skip `domain_name` and `route53_zone_id`, the module creates an HTTP-only ALB and you access Airbyte via the raw ALB DNS name.

### What you must create manually

| Resource | How | Notes |
|---|---|---|
| **Domain name** | Register via Route53 or any registrar | e.g. `example.com` |
| **Route53 hosted zone** | AWS Console → Route53 → Create hosted zone | One zone per domain; copy the zone ID |
| **NS delegation** (if using an external registrar) | Add the Route53 nameservers to your registrar's DNS settings | Skip if domain is registered in Route53 |

Once you have the hosted zone, pass these two variables:

```hcl
domain_name     = "airbyte.example.com"   # FQDN for the Airbyte console
route53_zone_id = "Z0123456789ABCDEFGHIJ"  # From the Route53 hosted zone
```

### What Terraform manages automatically

**Both variants (EC2 and EKS):**

| Resource | Description |
|---|---|
| ACM certificate | Created and DNS-validated automatically |
| Route53 CNAME (cert validation) | `_abc123.airbyte.example.com` — Terraform creates and destroys this |

**EC2 variant only:**

| Resource | Description |
|---|---|
| Route53 A record | `airbyte.example.com → ALB DNS name` — fully Terraform-managed; destroyed on `terraform destroy` |

**EKS variant only:**

| Resource | Description |
|---|---|
| Route53 A record | Created by **ExternalDNS** (runs in the cluster) after the ALB comes up — **not** Terraform-managed |

> **EKS teardown note:** Because ExternalDNS creates the A record out-of-band, `terraform destroy` does not delete it. After destroying an EKS deployment, manually delete the A record from Route53 before re-deploying to avoid stale DNS.

### What Terraform never touches

- The hosted zone itself
- The root domain NS/SOA records
- Any other records in the zone

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Ctorresposada/airbyte_asset.git
cd airbyte_asset/terraform

# 2. Copy and edit the example tfvars
cp variables/dev.tfvars variables/myenv.tfvars
# Edit myenv.tfvars: set vpc_id, subnet IDs, domain_name, route53_zone_id
# Set deployment_type = "ec2" or "eks"

# 3. Initialize
terraform init
```

### EC2 deployment (one apply)

```bash
terraform apply -var-file=variables/myenv.tfvars
```

### EKS deployment (two applies)

```bash
# Pass 1 — creates all AWS infrastructure (EKS cluster, RDS, S3, IAM, etc.)
terraform apply -var-file=variables/myenv.tfvars

# Pass 2 — installs Helm charts once the cluster is up
terraform apply -var-file=variables/myenv.tfvars -var eks_cluster_ready=true
```

## Required Inputs

| Variable | Type | Description |
|---|---|---|
| `project_name` | `string` | Name prefix for all resources (e.g. `acme-airbyte`) |
| `environment` | `string` | Deployment environment (`dev`, `staging`, `prod`) |
| `vpc_id` | `string` | ID of the existing VPC |
| `private_subnet_ids` | `list(string)` | Private subnets for EC2/nodes + RDS (min 2 AZs) |
| `public_subnet_ids` | `list(string)` | Public subnets for the ALB |

## Optional Inputs

### Shared (both variants)

| Variable | Type | Default | Description |
|---|---|---|---|
| `deployment_type` | `string` | `"ec2"` | `"ec2"` or `"eks"` |
| `aws_region` | `string` | `us-east-1` | AWS region |
| `domain_name` | `string` | `""` | FQDN for Airbyte (e.g. `airbyte.example.com`) |
| `route53_zone_id` | `string` | `""` | Route53 zone for DNS + cert validation |
| `alb_certificate_arn` | `string` | `""` | Existing ACM cert ARN (skips auto-creation) |
| `rds_instance_class` | `string` | `db.t3.micro` | RDS instance class |
| `rds_multi_az` | `bool` | `false` | Enable Multi-AZ (recommended for prod) |
| `rds_deletion_protection` | `bool` | `false` | Enable deletion protection (recommended for prod) |
| `log_retention_days` | `number` | `90` | CloudWatch log retention |
| `tags` | `map(string)` | `{}` | Additional tags for all resources |

### EC2-only

| Variable | Type | Default | Description |
|---|---|---|---|
| `instance_type` | `string` | `m6a.2xlarge` | EC2 instance type (min 8 vCPU / 32 GB) |
| `ami_architecture` | `string` | `arm64` | `arm64` for Graviton, `x86_64` for Intel/AMD |
| `ebs_volume_size` | `number` | `50` | Root volume size in GB |

### EKS-only

| Variable | Type | Default | Description |
|---|---|---|---|
| `eks_kubernetes_version` | `string` | `1.32` | Kubernetes version |
| `eks_node_instance_type` | `string` | `m6a.xlarge` | Node group instance type |
| `eks_node_desired_size` | `number` | `2` | Node group desired count |
| `eks_node_min_size` | `number` | `2` | Node group minimum count |
| `eks_node_max_size` | `number` | `4` | Node group maximum count |
| `eks_airbyte_chart_version` | `string` | `2.1.0` | Airbyte Helm chart version |

## Outputs

| Output | EC2 | EKS | Description |
|---|---|---|---|
| `airbyte_url` | ✓ | ✓ | HTTPS URL for the Airbyte console |
| `airbyte_admin_secret_arn` | ✓ | ✓ | Secrets Manager ARN with admin credentials |
| `rds_endpoint` | ✓ | ✓ | RDS PostgreSQL endpoint |
| `instance_role_arn` | EC2 instance role | EKS IRSA role | IAM role to attach additional connector policies |
| `kms_key_arn` | ✓ | ✓ | KMS key encrypting all resources |
| `alb_dns_name` | ✓ | null | ALB DNS name (EC2 only; EKS ALB is controller-managed) |
| `asg_name` | ✓ | null | Auto Scaling Group name (EC2 only) |
| `eks_cluster_name` | null | ✓ | EKS cluster name |

## S3 Bucket

The module creates an S3 bucket (`<project_name>-<environment>`) used by Airbyte as its workload storage backend, replacing the default local PVC storage inside the kind cluster:

| Prefix | Purpose | When it gets populated |
|---|---|---|
| `logs/` | Connector sync logs | When a sync job runs |
| `state/` | State payloads (incremental sync cursors) | When a sync completes and saves its checkpoint |
| `workload-output/` | Sync output data (temporary staging) | During active syncs |

The bucket is empty after initial deployment — objects appear once you create connections and run syncs.

## Post-Deployment

### 1. Get admin credentials

**EC2 variant** — credentials are written to Secrets Manager at first boot:
```bash
aws secretsmanager get-secret-value \
  --secret-id "<project>-<env>/airbyte-admin-creds" \
  --query SecretString --output text
```

**EKS variant** — credentials live in a Kubernetes secret created by the Helm chart:
```bash
# Email (username)
kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-email}' | base64 --decode

# Password
kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-password}' | base64 --decode
```

> To run kubectl commands you need kubeconfig access to the cluster:
> ```bash
> aws eks update-kubeconfig --region <aws_region> --name <eks_cluster_name>
> ```
> The `eks_cluster_name` output from `terraform output` gives you the cluster name.

### 2. Access the console

Open the `airbyte_url` output in your browser. For EC2, `alb_dns_name` works too if no custom domain was configured.

### 3. Attach connector permissions

Add policies to `instance_role_arn` for any AWS services Airbyte connectors need to reach (e.g. S3, Redshift, Glue).

## Repository Structure

```
terraform/
├── main.tf                              # Root module — deployment_type toggle, both module blocks
├── variables.tf                         # All deployment inputs (shared + EC2-only + EKS-only)
├── outputs.tf                           # Key outputs (try() across both variants)
├── providers.tf                         # AWS + kubernetes + helm providers
├── terraform.tf                         # Version constraints
├── variables/
│   └── dev.tfvars                       # Example environment config (deployment_type = "ec2")
├── modules/
│   ├── airbyte-ec2/                     # EC2 variant: abctl/kind-in-Docker (~$150/mo)
│   │   ├── main.tf                      # KMS, IAM, SGs, RDS, S3, ALB, ASG, ACM, Route53
│   │   ├── variables.tf / outputs.tf
│   │   ├── versions.tf
│   │   └── templates/
│   │       ├── user-data.sh.tpl         # EC2 bootstrap (Docker, abctl, Airbyte)
│   │       └── airbyte-values.yaml.tpl  # Helm values delivered via SSM
│   └── airbyte-eks/                     # EKS variant: Helm on managed Kubernetes (~$300-500/mo)
│       ├── main.tf                      # KMS, SGs, RDS, S3, Secrets Manager, CloudWatch
│       ├── iam.tf                       # IRSA roles (Airbyte, EBS CSI, ALB controller, ExternalDNS)
│       ├── eks.tf                       # EKS cluster, node group, add-ons, Helm releases
│       ├── dns.tf                       # ACM cert + Route53 validation record
│       ├── variables.tf / outputs.tf
│       ├── versions.tf
│       └── templates/
│           └── airbyte-values.yaml.tpl  # Helm values (IRSA auth, ALB Ingress, no ARM64 pins)
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

## EKS Deployment Notes

### Two-pass apply

The Helm/kubernetes providers are configured from the EKS cluster endpoint. Because the cluster doesn't exist on the first apply, Terraform can't initialize those providers yet. The `eks_cluster_ready` variable gates this:

```bash
# Pass 1 — eks_cluster_ready defaults to false; Helm provider skips initialization.
# Creates: EKS cluster, node group, RDS, S3, KMS, IAM/IRSA roles, ACM cert, security groups.
terraform apply -var-file=variables/myenv.tfvars

# Pass 2 — eks_cluster_ready=true tells the providers to connect to the now-existing cluster.
# Creates: EKS add-ons (vpc-cni, coredns, kube-proxy, ebs-csi), Airbyte Helm release,
#          AWS Load Balancer Controller, ExternalDNS.
terraform apply -var-file=variables/myenv.tfvars -var eks_cluster_ready=true
```

### Admin credentials (EKS)

Credentials are stored in a Kubernetes secret created by the Helm chart — see [Post-Deployment](#post-deployment) for the exact commands.

## Migrating from the previous module path

If you deployed before the EC2/EKS split, your Terraform state has resources under `module.airbyte.*`. After upgrading, run these state moves before applying:

```bash
terraform state mv 'module.airbyte' 'module.airbyte_ec2[0]'
```

Or for a complete migration, run `terraform state mv` for each resource — see `terraform state list` output for the full set.

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

#### Step 1 — Retrieve Airbyte API credentials

The connectors example authenticates to Airbyte using a client ID and secret (OAuth2 machine-to-machine). Retrieve them based on your deployment variant:

**EKS variant** — secrets live in the Kubernetes cluster:

```bash
# Point kubectl at the EKS cluster (run once)
aws eks update-kubeconfig --region <aws_region> --name <eks_cluster_name>

# Client ID
kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-client-id}' | base64 --decode && echo

# Client secret
kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-client-secret}' | base64 --decode && echo
```

**EC2 variant** — Airbyte runs inside a kind cluster on the EC2 instance. SSH in first:

```bash
# SSH into the EC2 instance (replace <instance-id> with the ASG instance)
aws ssm start-session --target <instance-id>

# Then inside the instance:
kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-client-id}' | base64 --decode && echo

kubectl get secret airbyte-auth-secrets -n airbyte \
  -o jsonpath='{.data.instance-admin-client-secret}' | base64 --decode && echo
```

> The EC2 instance ID can be found in the AWS Console → EC2 → Instances, or via:
> `aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=<asg_name>" --query 'Reservations[].Instances[].InstanceId' --output text`

#### Step 2 — Get the workspace ID

Open the Airbyte UI, navigate to any workspace, and copy the ID from the URL:

```
https://airbyte.example.com/workspaces/15f8dc70-6c05-40aa-bbbd-23025f882cb0/...
                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                        This is your workspace_id
```

Alternatively: **Settings → General** in the Airbyte UI shows the workspace ID.

#### Step 3 — Create your tfvars and apply

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
| `airbyte_client_id` | From K8s secret `airbyte-auth-secrets` → `instance-admin-client-id` (see Step 1) |
| `airbyte_client_secret` | From K8s secret `airbyte-auth-secrets` → `instance-admin-client-secret` (see Step 1) |
| `workspace_id` | From the Airbyte UI URL (see Step 2) |
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
