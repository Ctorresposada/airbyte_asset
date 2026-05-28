variable "create" {
  description = "Whether this stack should provision its resources. Set to false to soft-delete everything the stack manages while preserving state and code."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Target deployment environment"
  type        = string
}

variable "aws_region" {
  description = "Target deployment region"
  type        = string
}

variable "team" {
  description = "Team that manages this project"
  type        = string
}

variable "account_id" {
  description = "AWS account ID of the target account; used to construct the cross-account assume_role ARN"
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "company_name" {
  description = "Company name prefix used in resource names and to look up shared resources by tag."
  type        = string
}

# ---------------------------------------------------------------------------
# Airbyte API provider configuration
# ---------------------------------------------------------------------------

variable "airbyte_hostname" {
  description = "Hostname or IP of the self-hosted Airbyte EC2 instance (no protocol prefix). Used to construct the Airbyte API server_url. The stack must be applied from a network with VPN access to this host."
  type        = string
}

variable "airbyte_client_id" {
  description = "Airbyte API client ID for OAuth2 client-credentials authentication. Pass via TF_VAR_airbyte_client_id."
  type        = string
  default     = ""
  sensitive   = true
}

variable "airbyte_client_secret" {
  description = "Airbyte API client secret for OAuth2 client-credentials authentication. Pass via TF_VAR_airbyte_client_secret."
  type        = string
  default     = ""
  sensitive   = true
}

#tflint-ignore: terraform_unused_declarations
variable "api_token" {
  description = "Airbyte API token"
  type        = string
  sensitive   = true
}

variable "airbyte_workspace_id" {
  description = "Airbyte workspace ID under which all sources, destinations, and connections are created."
  type        = string
}

# ---------------------------------------------------------------------------
# Destination (S3 data lake)
# ---------------------------------------------------------------------------

variable "destination_s3_bucket_name" {
  description = "Name of the S3 bucket used as the Airbyte S3 destination (data lake landing zone)."
  type        = string
}

# ---------------------------------------------------------------------------
# Secrets Manager ARNs for source credentials
# ---------------------------------------------------------------------------

#tflint-ignore: terraform_unused_declarations
variable "oracle_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Oracle DB credentials. Expected JSON keys: host, port, sid, username, password, ssh_host, ssh_port, ssh_username, ssh_private_key."
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "mssql_secret_arn" {
  description = "ARN of the Secrets Manager secret holding SQL Server credentials. Expected JSON keys: host, port, database, username, password, ssh_host, ssh_port, ssh_username, ssh_private_key."
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "google_drive_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Google service account JSON used by the Google Drive source. Expected JSON key: service_account_json (a JSON string)."
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "docebo_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Docebo API credentials. Expected JSON key: api_key."
  type        = string
}

variable "s3_credentials_secret_id" {
  description = "ID or ARN of the Secrets Manager secret holding AWS credentials for the Airbyte S3 destination connector. Expected JSON keys: access_key_id, secret_access_key."
  type        = string
  default     = "airbyte/client-credentials"
}

# ---------------------------------------------------------------------------
# Source-specific configuration
# ---------------------------------------------------------------------------

#tflint-ignore: terraform_unused_declarations
variable "google_drive_folder_url" {
  description = "Google Drive folder URL to sync from (e.g. https://drive.google.com/drive/folders/<folder_id>)."
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "docebo_connector_definition_id" {
  description = "Airbyte connector definition ID for the custom Docebo connector (UUID). Created in Airbyte ahead of time by the developer (Isadora)."
  type        = string
}

#tflint-ignore: terraform_unused_declarations
variable "docebo_base_url" {
  description = "Base URL for the Docebo API (e.g. https://yourcompany.docebosaas.com)."
  type        = string
}

# ---------------------------------------------------------------------------
# Connection schedules (cron expressions, Quartz format)
# ---------------------------------------------------------------------------

#tflint-ignore: terraform_unused_declarations
variable "oracle_sync_cron" {
  description = "Cron expression (Quartz format) for the Oracle to S3 connection sync schedule. Default is hourly."
  type        = string
  default     = "0 0 * * * ?"
}

#tflint-ignore: terraform_unused_declarations
variable "mssql_sync_cron" {
  description = "Cron expression (Quartz format) for the SQL Server to S3 connection sync schedule. Default is hourly."
  type        = string
  default     = "0 0 * * * ?"
}

#tflint-ignore: terraform_unused_declarations
variable "google_drive_sync_cron" {
  description = "Cron expression (Quartz format) for the Google Drive to S3 connection sync schedule. Default is hourly."
  type        = string
  default     = "0 0 * * * ?"
}

#tflint-ignore: terraform_unused_declarations
variable "docebo_sync_cron" {
  description = "Cron expression (Quartz format) for the Docebo to S3 connection sync schedule. Default is hourly."
  type        = string
  default     = "0 0 * * * ?"
}
