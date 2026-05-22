# Terraform Ingestion Stack

This stack provisions the AWS infrastructure for the Region 20 Data Lake ingestion layer: the S3 medallion storage (raw / bronze / silver), the Glue Catalog databases that sit on top of bronze and silver, the self-managed Airbyte compute platform that loads data into the lake, and the dedicated Airbyte Cloud IAM user with its credentials secret. It also wires up the cross-account replication policy that lets the Ascender source account write into the raw landing zone. State is stored in the shared `region-20-tf-state` S3 bucket under the `ingestion/terraform.tfstate` key, using Terraform workspaces keyed by environment name.

<!-- BEGIN_TF_DOCS -->
## Data sources

| Source         | Type              | Ingestion method                   | Format  |
| -------------- | ----------------- | ---------------------------------- | ------- |
| Oracle APEX    | On-premises DB    | Airbyte Cloud (JDBC + CDC)         | Parquet |
| SQL Server (TAS) | On-premises DB  | Airbyte Cloud (JDBC + CDC)         | Parquet |
| Docebo         | REST API          | Airbyte Cloud (custom connector)   | Parquet |
| Ascender       | Manual file drop  | S3 raw → Airbyte                   | CSV     |
| TEA            | Manual file drop  | S3 raw → Airbyte                   | CSV     |
| ESCWorks       | Manual file drop  | S3 raw → Airbyte                   | CSV     |

## Architecture overview

```
On-premises Sources                                                    SaaS
─────────────────                                                     ───────
  Oracle APEX (JDBC)  ──┐
  SQL Server / TAS    ──┤-----------------------------► Airbyte Cloud ──► S3 Bronze (Parquet/Iceberg)
  Docebo API          ──┘                                              │
                                                                       ▼
Manual file drops                        
(Ascender, TEA, ESCWorks) ─► S3 Raw (landing zone) -> Airbyte Cloud ──► S3 Bronze (Parquet/Iceberg)
                                                                      ▼
                                                            Glue Catalog (bronze_db)
                                                                      │
                                                                      ▼
                                                          dbt Cloud (transformation)
                                                                      │
                                                                      ▼
                                                          S3 Silver (Parquet/Iceberg)
                                                                      │
                                                                      ▼
                                                          Redshift DW Gold (BI-ready)
                    ```

## What this stack provisions

### S3 medallion buckets ([s3.tf](s3.tf))

Three buckets keyed by layer, named `<bucket_name>-<environment>` (e.g., `escr20-bronze-dev`). Each bucket is created with:

- Public access fully blocked (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`).
- SSE-S3 (`AES256`) default encryption with bucket-key enabled.
- Versioning enabled.
- A lifecycle policy that transitions current objects to `STANDARD_IA` after `transition_ia` days, to `GLACIER` after `transition_glacier` days, expires them after `expiration_days`, and aborts incomplete multipart uploads after 7 days.

#### Raw bucket prefixes

Manual file drops are organised by source under the raw landing zone:

```
s3://escr20-landing-zone-raw-{env}/
  ├── ascender/    (Ascender files — e.g. ascender_user_YYYYMMDD.csv)
  ├── tea/         (TEA files — e.g. tea_students_YYYYMMDD.csv)
  └── connect20/   (Connect20 files)
```

File naming convention:

```
Daily:   {source}_{table}_{YYYYMMDD}.csv
Hourly:  {source}_{table}_{YYYYMMDD}_{HHMMSS}.csv
Examples:
  ascender_user_20260520.csv
  ascender_user_20260520_020000.csv
  tea_students_20260520.csv
  tea_students_20260520_140000.csv
```

These three prefixes are materialised as zero-byte objects so the folders exist before any file lands. A bucket policy on the raw bucket grants the Ascender source account's S3 CRR service role (`arn:aws:iam::472646798982:role/service-role/s3crr_role_for_esc20-ascender-data-warehouse-798982-us-east-1`) permission to replicate objects into the `ascender/` prefix only, plus the bucket-level `List*` / `GetBucketVersioning` actions S3 requires for destination validation.

### Glue Catalog databases ([glue_catalog.tf](glue_catalog.tf))

One Glue database per entry in `var.glue_databases`, named `<database_name>_<environment>`. Each database's `location_uri` resolves to the matching S3 layer bucket.

| Database                  | Purpose                                                          |
| ------------------------- | ---------------------------------------------------------------- |
| `escr20_bronze_{env}`     | External table definitions pointing to S3 Bronze                 |
| `escr20_silver_{env}`     | External table definitions pointing to S3 Silver (Iceberg)       |

### Airbyte compute ([airbyte.tf](airbyte.tf))

Wraps `../modules/airbyte` and supplies it with shared infrastructure:

- AMI: latest Amazon Linux 2023 x86_64, resolved at plan time from the public SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`.
- Networking: the VPC and `Tier=private-app` subnets are discovered by tag from the shared networking stack — this stack does not create its own VPC.
- KMS: a dedicated CMK (`alias/<company>-<env>-airbyte`) with key rotation enabled and a 14-day deletion window. The key policy grants:
  - Full key administration to the account root.
  - The EC2 Auto Scaling service-linked role (`AWSServiceRoleForAutoScaling`) the encrypt/decrypt/grant permissions it needs for EBS volume encryption on ASG-launched instances.
  - The regional CloudWatch Logs service principal encrypt/decrypt access scoped via `kms:EncryptionContext:aws:logs:arn` to the Airbyte log group only.

The module itself stands up the Airbyte EC2 ASG, the RDS PostgreSQL config database, the Airbyte logs/artifacts S3 bucket, the CloudWatch log group, and the ALB. The ALB is currently disabled (`create_alb = false`) pending DNS and ACM certificate provisioning. An optional `aws_vpc_security_group_ingress_rule` loop opens port 80 directly on the EC2 instance from `var.airbyte_instance_direct_cidr_blocks` for debugging — leave this list empty in production.

### Airbyte Cloud IAM user ([airbyte_iam.tf](airbyte_iam.tf))

A dedicated long-lived IAM user `airbyte-cloud-data-ingestion` (path `/airbyte/`) with a programmatic access key. Static credentials are required because Airbyte Cloud does not support SSO for external destinations. The attached customer-managed policy grants least-privilege access only to:

- The bronze S3 bucket (`escr20-bronze-dev`): `PutObject`, `GetObject`, `DeleteObject`, `ListBucket`, `GetBucketLocation`.
- The bronze Glue catalog database (`escr20_bronze_dev`) and its tables: `CreateTable`, `UpdateTable`, `DeleteTable`, `GetTable`, `GetTables`, `GetDatabase`, `GetDatabases`, `CreateDatabase`.
- The Airbyte CMK: `Decrypt`, `GenerateDataKey`, `DescribeKey` (required so the user can read/write encrypted objects).

### Airbyte credentials secret ([airbyte_secrets.tf](airbyte_secrets.tf))

The access key and secret access key are written into a Secrets Manager secret named `airbyte/client-credentials`, encrypted with the Airbyte CMK. A resource policy on the secret restricts read access to the account root (full access) and the Airbyte IAM user itself (`GetSecretValue`, `DescribeSecret`). Recovery window is 14 days; automatic rotation is intentionally not configured in dev.

## File structure

```
terraform/ingestion/
  ├── main.tf              # aws_caller_identity data source
  ├── providers.tf         # AWS provider + cross-account assume_role
  ├── terraform.tf         # required_version, required_providers, S3 backend
  ├── locals.tf            # local.name = "<company>-<env>"
  ├── variables.tf         # input variable definitions
  ├── outputs.tf           # output values (bucket names, ARNs, database names, Airbyte metadata)
  ├── s3.tf                # S3 buckets, lifecycle, encryption, versioning, raw prefixes, Ascender CRR policy
  ├── glue_catalog.tf      # Glue Catalog databases
  ├── airbyte.tf           # Airbyte module wrapping + KMS CMK + VPC/subnet/AMI lookups
  ├── airbyte_iam.tf       # Airbyte Cloud IAM user, access key, least-privilege policy
  ├── airbyte_secrets.tf   # Secrets Manager secret holding Airbyte credentials
  └── variables/
        └── dev.tfvars     # Development environment values
```

## Soft-delete switch

All resources outside of `aws_glue_catalog_database`, `aws_s3_bucket`, and the Airbyte IAM/Secrets resources are gated on `var.create`. Set `create = false` to soft-delete the conditional resources while keeping state and code intact — useful for tearing down compute (Airbyte EC2/RDS/ALB, KMS key) without losing the catalog and storage layer.

<!-- END_TF_DOCS -->
