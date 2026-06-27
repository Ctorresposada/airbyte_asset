# Example: Oracle + SQL Server sources → S3 Data Lake destination
# Variables for a complete working deployment.

# ---------------------------------------------------------------------------
# Airbyte provider
# ---------------------------------------------------------------------------

variable "airbyte_server_url" {
  description = "Airbyte API URL (e.g. 'https://airbyte-dev.example.com/api/public/v1/')."
  type        = string
}

variable "airbyte_token_url" {
  description = "Airbyte token endpoint. For self-hosted abctl: 'https://<domain>/api/v1/applications/token'."
  type        = string
}

variable "airbyte_client_id" {
  description = "Airbyte API client ID (from K8s secret airbyte-auth-secrets: instance-admin-client-id)."
  type        = string
  sensitive   = true
}

variable "airbyte_client_secret" {
  description = "Airbyte API client secret (from K8s secret airbyte-auth-secrets: instance-admin-client-secret)."
  type        = string
  sensitive   = true
}

variable "workspace_id" {
  description = "Airbyte workspace ID (from the URL in the Airbyte UI)."
  type        = string
}

# ---------------------------------------------------------------------------
# AWS
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where the source RDS instances and Secrets Manager secrets reside."
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for Secrets Manager lookups."
  type        = string
  default     = "AdminSandbox"
}

# ---------------------------------------------------------------------------
# Oracle source
# ---------------------------------------------------------------------------

variable "oracle_host" {
  description = "Oracle RDS endpoint."
  type        = string
}

variable "oracle_port" {
  description = "Oracle port."
  type        = number
  default     = 1521
}

variable "oracle_service_name" {
  description = "Oracle service name."
  type        = string
}

variable "oracle_username" {
  description = "Oracle database username."
  type        = string
}

variable "oracle_password_secret_arn" {
  description = "Secrets Manager ARN containing the Oracle password (RDS managed secret)."
  type        = string
}

variable "oracle_schemas" {
  description = "Oracle schemas to sync."
  type        = list(string)
}

# ---------------------------------------------------------------------------
# SQL Server source
# ---------------------------------------------------------------------------

variable "mssql_host" {
  description = "SQL Server RDS endpoint."
  type        = string
}

variable "mssql_port" {
  description = "SQL Server port."
  type        = number
  default     = 1433
}

variable "mssql_database" {
  description = "SQL Server database name."
  type        = string
}

variable "mssql_username" {
  description = "SQL Server database username."
  type        = string
}

variable "mssql_password_secret_arn" {
  description = "Secrets Manager ARN containing the SQL Server password (RDS managed secret)."
  type        = string
}

variable "mssql_schemas" {
  description = "SQL Server schemas to sync."
  type        = list(string)
  default     = ["dbo"]
}

# ---------------------------------------------------------------------------
# S3 Data Lake destination
# ---------------------------------------------------------------------------

variable "s3_bucket_name" {
  description = "S3 bucket name for the data lake."
  type        = string
}

variable "s3_bucket_region" {
  description = "AWS region of the S3 bucket."
  type        = string
  default     = "eu-west-1"
}

variable "s3_warehouse_location" {
  description = "S3 warehouse location for Iceberg tables (e.g. 's3://bucket/iceberg/')."
  type        = string
}

variable "s3_access_key_id" {
  description = "AWS access key ID for the S3 destination."
  type        = string
  sensitive   = true
}

variable "s3_secret_access_key" {
  description = "AWS secret access key for the S3 destination."
  type        = string
  sensitive   = true
}

variable "glue_database" {
  description = "Glue catalog database name for Iceberg tables."
  type        = string
  default     = "airbyte_asset_catalog"
}

variable "glue_account_id" {
  description = "AWS account ID for the Glue catalog."
  type        = string
}
