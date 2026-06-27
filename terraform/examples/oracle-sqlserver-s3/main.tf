# Example: Oracle + SQL Server → S3 Data Lake (Iceberg + Glue Catalog)
#
# This example creates:
#   - Oracle source connector (community, service_name connection)
#   - SQL Server source connector
#   - S3 Data Lake destination (Iceberg format, Glue catalog)
#   - Connection: Oracle → S3 (prefix: oracle_, full refresh)
#   - Connection: SQL Server → S3 (prefix: sqlserver_, full refresh)
#
# Passwords are fetched from AWS Secrets Manager at plan time.

# ---------------------------------------------------------------------------
# Airbyte API token — self-hosted abctl uses a custom token endpoint
# ---------------------------------------------------------------------------

data "external" "airbyte_token" {
  program = ["bash", "-c", <<-EOT
    curl -s -X POST "${var.airbyte_token_url}" \
      -H "Content-Type: application/json" \
      -d "{\"client_id\":\"${var.airbyte_client_id}\",\"client_secret\":\"${var.airbyte_client_secret}\",\"grant-type\":\"client_credentials\"}"
  EOT
  ]
}

# ---------------------------------------------------------------------------
# Secrets Manager lookups — source DB passwords
# ---------------------------------------------------------------------------

data "aws_secretsmanager_secret_version" "oracle" {
  secret_id = var.oracle_password_secret_arn
}

data "aws_secretsmanager_secret_version" "mssql" {
  secret_id = var.mssql_password_secret_arn
}

locals {
  oracle_password = jsondecode(data.aws_secretsmanager_secret_version.oracle.secret_string)["password"]
  mssql_password  = jsondecode(data.aws_secretsmanager_secret_version.mssql.secret_string)["password"]
}

# ---------------------------------------------------------------------------
# Oracle source (community connector)
# ---------------------------------------------------------------------------

resource "airbyte_source" "oracle" {
  name          = "Oracle"
  workspace_id  = var.workspace_id
  definition_id = "b39a7370-74c3-45a6-ac3a-380d48520a83" # source-oracle

  configuration = jsonencode({
    host            = var.oracle_host
    port            = var.oracle_port
    connection_data = { connection_type = "service_name", service_name = var.oracle_service_name }
    schemas         = var.oracle_schemas
    username        = var.oracle_username
    password        = local.oracle_password
    encryption      = { encryption_method = "unencrypted" }
  })
}

# ---------------------------------------------------------------------------
# SQL Server source
# ---------------------------------------------------------------------------

resource "airbyte_source" "mssql" {
  name          = "SQL Server"
  workspace_id  = var.workspace_id
  definition_id = "b5ea17b1-f170-46dc-bc31-cc744ca984c1" # source-mssql

  configuration = jsonencode({
    host               = var.mssql_host
    port               = var.mssql_port
    database           = var.mssql_database
    schemas            = var.mssql_schemas
    username           = var.mssql_username
    password           = local.mssql_password
    replication_method = { method = "STANDARD" }
    ssl_method         = { ssl_method = "encrypted_trust_server_certificate" }
  })
}

# ---------------------------------------------------------------------------
# S3 Data Lake destination (Iceberg + Glue Catalog)
# ---------------------------------------------------------------------------

resource "airbyte_destination" "s3_data_lake" {
  name          = "S3 Data Lake"
  workspace_id  = var.workspace_id
  definition_id = "716ca874-520b-4902-9f80-9fad66754b89" # destination-s3-data-lake

  configuration = jsonencode({
    s3_bucket_name     = var.s3_bucket_name
    s3_bucket_region   = var.s3_bucket_region
    access_key_id      = var.s3_access_key_id
    secret_access_key  = var.s3_secret_access_key
    warehouse_location = var.s3_warehouse_location
    main_branch_name   = "main"
    catalog_type = {
      catalog_type  = "GLUE"
      database_name = var.glue_database
      glue_id       = var.glue_account_id
    }
  })
}

# ---------------------------------------------------------------------------
# Connection: Oracle → S3 Data Lake (full refresh)
# ---------------------------------------------------------------------------

resource "airbyte_connection" "oracle_to_s3" {
  name           = "Oracle to S3 Data Lake"
  source_id      = airbyte_source.oracle.source_id
  destination_id = airbyte_destination.s3_data_lake.destination_id
  prefix         = "oracle_"
  status         = "active"

  configurations = {
    streams = [
      {
        name      = "TEST"
        sync_mode = "full_refresh_overwrite"
      }
    ]
  }

  namespace_definition = "destination"

  schedule = {
    schedule_type = "manual"
  }
}

# ---------------------------------------------------------------------------
# Connection: SQL Server → S3 Data Lake (full refresh)
# ---------------------------------------------------------------------------

resource "airbyte_connection" "mssql_to_s3" {
  name           = "SQL Server to S3 Data Lake"
  source_id      = airbyte_source.mssql.source_id
  destination_id = airbyte_destination.s3_data_lake.destination_id
  prefix         = "sqlserver_"
  status         = "active"

  configurations = {
    streams = [
      {
        name      = "test"
        sync_mode = "full_refresh_overwrite"
      }
    ]
  }

  namespace_definition = "destination"

  schedule = {
    schedule_type = "manual"
  }
}
