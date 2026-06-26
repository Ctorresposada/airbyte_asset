# ---------------------------------------------------------------------------
# Oracle source (community connector)
# ---------------------------------------------------------------------------

data "airbyte_connector_configuration" "oracle" {
  count = var.create_oracle_source ? 1 : 0

  connector_name     = "source-oracle"
  connector_registry = "oss"

  configuration = {
    host            = var.oracle_host
    port            = var.oracle_port
    connection_data = { connection_type = "sid", sid = var.oracle_sid }
    schemas         = var.oracle_schemas
    encryption      = { encryption_method = "unencrypted" }
  }

  configuration_secrets = {
    username = var.oracle_username
    password = var.oracle_password
  }
}

resource "airbyte_source" "oracle" {
  count = var.create_oracle_source ? 1 : 0

  name          = var.oracle_name
  workspace_id  = var.workspace_id
  definition_id = data.airbyte_connector_configuration.oracle[0].definition_id
  configuration = data.airbyte_connector_configuration.oracle[0].configuration_json
}

# ---------------------------------------------------------------------------
# SQL Server source
# ---------------------------------------------------------------------------

data "airbyte_connector_configuration" "mssql" {
  count = var.create_mssql_source ? 1 : 0

  connector_name     = "source-mssql"
  connector_registry = "oss"

  configuration = {
    host     = var.mssql_host
    port     = var.mssql_port
    database = var.mssql_database
    schemas  = var.mssql_schemas
  }

  configuration_secrets = {
    username = var.mssql_username
    password = var.mssql_password
  }
}

resource "airbyte_source" "mssql" {
  count = var.create_mssql_source ? 1 : 0

  name          = var.mssql_name
  workspace_id  = var.workspace_id
  definition_id = data.airbyte_connector_configuration.mssql[0].definition_id
  configuration = data.airbyte_connector_configuration.mssql[0].configuration_json
}
