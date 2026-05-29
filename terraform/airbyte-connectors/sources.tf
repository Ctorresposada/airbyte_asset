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

# ---------------------------------------------------------------------------
# Google Drive source
# ---------------------------------------------------------------------------
data "airbyte_connector_configuration" "google_drive_source_config" {
  count = var.create ? 1 : 0

  connector_name = "source-google-drive"

  configuration = {
    streams = [
      {
        name  = "all_files"
        globs = ["**"]
        format = {
          filetype = "unstructured"
          strategy = "auto"
          processing = {
            mode = "local"
          }
          skip_unprocessable_files = true
        }
        schemaless                                = true
        validation_policy                         = "Emit Record"
        days_to_sync_if_history_is_full           = 3
        use_first_found_file_for_schema_discovery = false
      }
    ]
    folder_url = var.google_drive_folder_url
    credentials = {
      auth_type            = "Service"
      service_account_info = jsonencode(local.google_drive_creds)
    }
    delivery_method = {
      delivery_type                = "use_file_transfer"
      preserve_directory_structure = true
    }
  }
}

resource "airbyte_source" "google_drive" {
  count = var.create ? 1 : 0

  name          = "TEA Google Drive"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.google_drive_source_config[0].definition_id
  configuration = data.airbyte_connector_configuration.google_drive_source_config[0].configuration_json
}
