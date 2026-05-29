create                   = true
create_oracle_connection = false
environment              = "dev"
aws_region               = "us-east-1"
team                     = "devops"
company_name             = "region-20"
account_id               = "784590287037"

# Airbyte API endpoint. Replace with the actual private hostname or IP of the
# Airbyte EC2 instance reachable through the Client VPN.
airbyte_hostname     = "172.17.61.111:8000"
airbyte_workspace_id = "86c8759b-5b64-49f5-bb00-abaf1af53936"

# Destination
destination_s3_bucket_name = "escr20-bronze-dev"
glue_database_name         = "escr20_bronze_dev"

# Secrets Manager ARNs
mssql_secret_arn        = "" # TODO: fill in
google_drive_secret_arn = "" # TODO: fill in
docebo_secret_arn       = "" # TODO: fill in

# Oracle source
oracle_host         = "192.168.1.12"
oracle_port         = 1521
oracle_schemas      = ["BOLINF", "bolinf"]
oracle_username     = "c##airbyte"
oracle_tunnel_host  = "129.146.105.89"
oracle_tunnel_user  = "oracle"
oracle_service_name = "apexdev.priv.esc20.oraclevcn.com"

# Docebo custom connector
docebo_connector_definition_id = "" # Isadora's connector definition UUID
docebo_base_url                = "" # e.g. https://yourcompany.docebosaas.com

# Google Drive source
google_drive_folder_url = "" # Full Google Drive folder URL to sync from

# Per-connection cron schedules (Quartz syntax). Defaults are hourly.
oracle_sync_cron       = "0 0 * * * ?"
mssql_sync_cron        = "0 0 * * * ?"
google_drive_sync_cron = "0 0 * * * ?"
docebo_sync_cron       = "0 0 * * * ?"
