# Connectors Stack — Variables
# Optional stack for managing Airbyte source/destination connectors via Terraform.

# ---------------------------------------------------------------------------
# Airbyte provider
# ---------------------------------------------------------------------------

variable "airbyte_server_url" {
  description = "Airbyte API URL (e.g. 'https://airbyte-dev.example.com/api/v1')."
  type        = string
}

variable "airbyte_client_id" {
  description = "Airbyte API client ID. Found in K8s secret airbyte-auth-secrets (instance-admin-client-id)."
  type        = string
  sensitive   = true
}

variable "airbyte_client_secret" {
  description = "Airbyte API client secret. Found in K8s secret airbyte-auth-secrets (instance-admin-client-secret)."
  type        = string
  sensitive   = true
}

variable "workspace_id" {
  description = "Airbyte workspace ID. Find it in the Airbyte UI under Settings > General."
  type        = string
}

# ---------------------------------------------------------------------------
# Oracle source
# ---------------------------------------------------------------------------

variable "create_oracle_source" {
  description = "Whether to create the Oracle source connector."
  type        = bool
  default     = false
}

variable "oracle_name" {
  description = "Display name for the Oracle source in Airbyte."
  type        = string
  default     = "Oracle"
}

variable "oracle_host" {
  description = "Oracle database hostname or IP address."
  type        = string
  default     = ""
}

variable "oracle_port" {
  description = "Oracle database port."
  type        = number
  default     = 1521
}

variable "oracle_sid" {
  description = "Oracle System Identifier (SID)."
  type        = string
  default     = ""
}

variable "oracle_username" {
  description = "Oracle database username."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oracle_password" {
  description = "Oracle database password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oracle_schemas" {
  description = "List of Oracle schemas to sync."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# SQL Server source
# ---------------------------------------------------------------------------

variable "create_mssql_source" {
  description = "Whether to create the SQL Server source connector."
  type        = bool
  default     = false
}

variable "mssql_name" {
  description = "Display name for the SQL Server source in Airbyte."
  type        = string
  default     = "SQL Server"
}

variable "mssql_host" {
  description = "SQL Server hostname or IP address."
  type        = string
  default     = ""
}

variable "mssql_port" {
  description = "SQL Server port."
  type        = number
  default     = 1433
}

variable "mssql_database" {
  description = "SQL Server database name."
  type        = string
  default     = ""
}

variable "mssql_username" {
  description = "SQL Server database username."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mssql_password" {
  description = "SQL Server database password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mssql_schemas" {
  description = "List of SQL Server schemas to sync."
  type        = list(string)
  default     = ["dbo"]
}

# ---------------------------------------------------------------------------
# S3 Data Lake destination
# ---------------------------------------------------------------------------

variable "create_s3_destination" {
  description = "Whether to create the S3 Data Lake destination connector."
  type        = bool
  default     = false
}

variable "s3_destination_name" {
  description = "Display name for the S3 destination in Airbyte."
  type        = string
  default     = "S3 Data Lake"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for the data lake destination."
  type        = string
  default     = ""
}

variable "s3_bucket_path" {
  description = "Path prefix inside the S3 bucket (e.g. 'airbyte/raw')."
  type        = string
  default     = "airbyte"
}

variable "s3_bucket_region" {
  description = "AWS region of the S3 bucket."
  type        = string
  default     = "us-east-1"
}

variable "s3_format" {
  description = "Output format for S3 files. One of: Parquet, JSON, CSV."
  type        = string
  default     = "Parquet"
}

variable "s3_access_key_id" {
  description = "AWS access key ID for the S3 destination. Leave empty to use instance profile credentials."
  type        = string
  default     = ""
  sensitive   = true
}

variable "s3_secret_access_key" {
  description = "AWS secret access key for the S3 destination. Leave empty to use instance profile credentials."
  type        = string
  default     = ""
  sensitive   = true
}
