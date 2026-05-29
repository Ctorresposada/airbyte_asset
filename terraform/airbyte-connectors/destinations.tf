# ---------------------------------------------------------------------------
# S3 Data Lake destination
# ---------------------------------------------------------------------------
data "airbyte_connector_configuration" "data_lake_config" {
  count = var.create ? 1 : 0

  connector_name = "destination-s3-data-lake"

  configuration = {
    main_branch_name = "main"
    catalog_type = {
      glue_id       = var.account_id
      catalog_type  = "GLUE"
      database_name = var.glue_database_name
    }
    s3_bucket_name      = var.destination_s3_bucket_name
    s3_bucket_region    = data.aws_region.current[0].region
    access_key_id       = local.s3_creds["access_key_id"]
    secret_access_key   = local.s3_creds["secret_access_key"]
    warehouse_location  = "s3://${var.destination_s3_bucket_name}/"
    flush_batch_size_mb = 200
  }
}

resource "airbyte_destination" "data_lake" {
  count = var.create ? 1 : 0

  name          = "S3 Data Lake"
  workspace_id  = var.airbyte_workspace_id
  definition_id = data.airbyte_connector_configuration.data_lake_config[0].definition_id
  configuration = data.airbyte_connector_configuration.data_lake_config[0].configuration_json
}
