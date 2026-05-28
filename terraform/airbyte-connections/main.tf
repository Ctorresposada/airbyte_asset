# Stack: airbyte-connections
# Manages Airbyte sources, the S3 destination, and connections wiring them
# together on a self-hosted Airbyte instance reachable over the VPN.
#
# Provider 1.x exposes a single generic airbyte_source / airbyte_destination
# resource: pass a connector definition_id and a JSON `configuration` blob
# whose shape matches the connector's spec. The whole configuration attribute
# is sensitive so secrets are never written to plan/state human-readable form.

# ---------------------------------------------------------------------------
# S3 destination (shared by all four connections)
# ---------------------------------------------------------------------------
data "airbyte_connector_configuration" "data_lake_config" {
  count = var.create ? 1 : 0

  connector_name = "destination-aws-datalake"

  configuration = {
    bucket_name                 = var.destination_s3_bucket_name
    region                      = data.aws_region.current[0].region
    lakeformation_database_name = "escr20_bronze_dev"
    credentials = {
      credentials_title     = "IAM User"
      aws_access_key_id     = local.s3_creds["access_key_id"]
      aws_secret_access_key = local.s3_creds["secret_access_key"]
    }
  }
}

resource "airbyte_destination" "data_lake" {
  count = var.create ? 1 : 0

  name          = "S3 Data Lake"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.data_lake_config[0].definition_id
  configuration = data.airbyte_connector_configuration.data_lake_config[0].configuration_json
}

