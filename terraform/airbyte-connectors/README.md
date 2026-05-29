# airbyte-connections

Terraform stack that declares Airbyte **sources**, the shared **S3 destination**, and the **connections** wiring them together on the self-hosted Airbyte instance.

## What this stack manages

Using the `airbytehq/airbyte` provider (v1.x) against a self-hosted Airbyte EC2 instance:

| Resource | Purpose |
|---|---|
| `airbyte_destination.s3` | S3 destination writing Parquet files into the data-lake landing bucket. Uses role-based authentication (no static keys). |
| `airbyte_source.oracle` | Oracle DB source over SSH key tunnel. |
| `airbyte_source.mssql` | SQL Server source over SSH key tunnel. |
| `airbyte_source.google_drive` | Google Drive folder source using a service account. |
| `airbyte_source.docebo` | Docebo custom connector (definition built outside Terraform; referenced by `definition_id`). |
| `airbyte_connection.<source>_to_s3` | Four connections (one per source), each on a Quartz cron schedule. |

All Airbyte resources are gated on `var.create` so the stack can be soft-deleted by flipping `create = false` in the tfvars.

## How to apply

The Airbyte API is on a private EC2 instance — apply must happen **from a machine connected to the Client VPN**. There is intentionally **no GitHub Actions workflow** for this stack.

```bash
cd terraform/airbyte-connections

# Export Airbyte API credentials (never store in tfvars or state in cleartext)
export TF_VAR_airbyte_client_id="..."
export TF_VAR_airbyte_client_secret="..."

terraform init
terraform workspace select dev 2>/dev/null || terraform workspace new dev
terraform plan  -var-file=variables/dev.tfvars
terraform apply -var-file=variables/dev.tfvars
```

To soft-delete: set `create = false` in `variables/dev.tfvars` and apply.

## Variables: tfvars vs environment

| Source | Variables |
|---|---|
| `variables/dev.tfvars` (committed) | `create`, `environment`, `aws_region`, `team`, `company_name`, `account_id`, `airbyte_hostname`, `airbyte_workspace_id`, `destination_s3_bucket_name`, `destination_s3_role_arn`, all `*_secret_arn`, `docebo_connector_definition_id`, `docebo_base_url`, `google_drive_folder_url`, all `*_sync_cron` |
| Environment vars (required) | `TF_VAR_airbyte_client_id`, `TF_VAR_airbyte_client_secret` |

The two Airbyte client credentials are marked `sensitive = true` and must be exported as `TF_VAR_*` env vars before running plan/apply.

## How secrets are fetched

All source-side credentials live in AWS Secrets Manager. The stack:

1. Reads each secret via `data "aws_secretsmanager_secret_version" "<source>"` (gated on `var.create`).
2. `jsondecode`s the `secret_string` in `locals.tf` into `local.<source>_creds`.
3. Passes the decoded fields into the connector's `configuration` JSON (which is a `(String, Sensitive)` attribute, so values are redacted in plan output).

Expected secret payload schemas:

```jsonc
// oracle_secret_arn
{
  "host": "...", "port": 1521, "sid": "ORCL",
  "username": "...", "password": "...",
}

// mssql_secret_arn
{
  "host": "...", "port": 1433, "database": "mydb",
  "username": "...", "password": "...",
}

// google_drive_secret_arn
{ "service_account_json": "{ ... full service-account JSON as a string ... }" }

// docebo_secret_arn
{ "api_key": "..." }
```

Secret ARNs and their payload shapes must be created out-of-band before applying this stack (typical pattern: managed by the `security` or `ingestion` stack).
