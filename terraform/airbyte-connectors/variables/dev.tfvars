create                   = true           # Master toggle; false soft-deletes all Airbyte connector resources, ex true
create_oracle_connection = true           # Independently controls the Oracle->S3 Airbyte connection; false removes it without touching other connections, ex true
environment              = "dev"          # Deployment environment; drives resource names and workspace, ex "dev"
aws_region               = "us-east-1"    # Target AWS region, ex "us-east-1"
team                     = "devops"       # Owning team tag, ex "devops"
company_name             = "region-20"    # Resource name prefix, ex "region-20"
account_id               = "784590287037" # Target AWS account ID; used in IAM policy conditions, ex "784590287037"

# Airbyte API endpoint. Replace with the actual private hostname or IP of the
# Airbyte EC2 instance reachable through the Client VPN.
airbyte_hostname     = "172.17.55.75:8000"                    # IP:port of the Airbyte EC2 instance; Terraform provider reaches it through the Client VPN, ex "172.17.55.75:8000"
airbyte_workspace_id = "86c8759b-5b64-49f5-bb00-abaf1af53936" # UUID of the Airbyte workspace; all sources/destinations/connections are created here, ex "86c8759b-5b64-49f5-bb00-abaf1af53936"

# Destination
destination_s3_bucket_name = "escr20-bronze-dev" # S3 bucket receiving raw data from all Airbyte connections (bronze layer), ex "escr20-bronze-dev"
glue_database_name         = "escr20_bronze_dev" # Glue Catalog database for Airbyte-managed tables; must match the bronze DB in ingestion stack, ex "escr20_bronze_dev"

# Secrets Manager ARNs
mssql_secret_arn    = ""                                 # TODO: fill in -- Secrets Manager ARN holding SQL Server credentials for the MSSQL source
google_drive_sm_arn = "airbyte/google-drive-credentials" # Secrets Manager secret ID or ARN for the Google Drive service account JSON key, ex "airbyte/google-drive-credentials"
docebo_secret_arn   = ""                                 # TODO: fill in -- Secrets Manager ARN holding Docebo API credentials

# Oracle source
oracle_host         = "192.168.1.12"                     # Oracle DB hostname reachable through the SSH tunnel via the OCI bastion, ex "192.168.1.12"
oracle_port         = 1521                               # Oracle DB listener port; default is 1521, ex 1521
oracle_schemas      = ["BOLINF", "bolinf"]               # Oracle schemas to replicate; must match case exactly as stored in the DB, ex ["BOLINF", "bolinf"]
oracle_username     = "c##airbyte"                       # Oracle user Airbyte connects as; requires SELECT on all tables in the target schemas, ex "c##airbyte"
oracle_tunnel_host  = "129.146.105.89"                   # OCI bastion hostname or IP used for SSH port-forwarding to the Oracle DB, ex "129.146.105.89"
oracle_tunnel_user  = "oracle"                           # SSH username on the OCI bastion for the tunnel connection, ex "oracle"
oracle_service_name = "apexdev.priv.esc20.oraclevcn.com" # Oracle service name (SID alias) used in the JDBC connection string, ex "apexdev.priv.esc20.oraclevcn.com"

# Docebo custom connector
docebo_connector_definition_id = "" # UUID of the custom Docebo Airbyte connector definition; Isadora's connector UUID from Airbyte UI
docebo_base_url                = "" # Docebo API base URL; no trailing slash, ex "https://yourcompany.docebosaas.com"

# Google Drive source
google_drive_folder_url = "https://drive.google.com/drive/folders/0AC5xbBuRiUvXUk9PVA" # Google Drive folder URL containing TEA source files Airbyte syncs to S3, ex "https://drive.google.com/drive/folders/0AC5xbBuRiUvXUk9PVA"

# Per-connection cron schedules (Quartz syntax). Defaults are hourly.
oracle_sync_cron       = "0 0 * * * ?" # Quartz cron for Oracle full-refresh schedule; "0 0 * * * ?" fires at the top of every hour, ex "0 0 * * * ?"
mssql_sync_cron        = "0 0 * * * ?" # Quartz cron for MSSQL incremental sync schedule, ex "0 0 * * * ?" (hourly)
google_drive_sync_cron = "0 0 * * * ?" # Quartz cron for Google Drive sync schedule, ex "0 0 * * * ?" (hourly)
docebo_sync_cron       = "0 0 * * * ?" # Quartz cron for Docebo sync schedule, ex "0 0 * * * ?" (hourly)
