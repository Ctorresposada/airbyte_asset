# ---------------------------------------------------------------------------
# Oracle source
# ---------------------------------------------------------------------------
data "airbyte_connector_configuration" "oracle_source_config" {
  count = var.create ? 1 : 0

  connector_name = "source-oracle"

  configuration = {
    port     = var.oracle_port
    host     = var.oracle_host
    schemas  = var.oracle_schemas
    password = local.oracle_creds["db_password"]
    username = var.oracle_username
    encryption = {
      encryption_method    = "client_nne"
      encryption_algorithm = "AES256"
    }
    tunnel_method = {
      ssh_key       = local.oracle_creds["ssh_key"]
      tunnel_host   = var.oracle_tunnel_host
      tunnel_port   = 22
      tunnel_user   = var.oracle_tunnel_user
      tunnel_method = "SSH_KEY_AUTH"
    }
    connection_data = {
      service_name    = var.oracle_service_name
      connection_type = "service_name"
    }
  }
}

resource "airbyte_source" "oracle" {
  count = var.create ? 1 : 0

  name          = "Oracle DB Region 20"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.oracle_source_config[0].definition_id
  configuration = data.airbyte_connector_configuration.oracle_source_config[0].configuration_json
}
