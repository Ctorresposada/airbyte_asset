create           = true                # Provision resources; false soft-deletes while keeping state
environment      = "prod"              # Deployment env; drives names, workspace, and -prod bucket/DB suffixes
aws_region       = "us-east-1"         # Target region; changing it relocates all resources
team             = "devops"            # Owning team tag
company_name     = "region-20"         # Name prefix and shared-resource tag lookups
account_id       = "029750300494"      # Target AWS account; builds the cross-account assume-role ARN
oci_bastion_host = "129.146.105.89/32" # OCI bastion CIDR; Airbyte SG egress :22 target for the Oracle source
tas_bastion_host = "69.147.58.13/32"   # TAS bastion CIDE, Airbyte SG egress :22 for the MSSQL source

# S3 layer buckets. name gets a -<env> suffix; transition_*/expiration_days set the lifecycle (days).
buckets = {
  raw    = { name = "escr20-landing-zone-raw", layer = "raw", transition_ia = 100, transition_glacier = 365, expiration_days = 2555 } # landing zone for all sources
  bronze = { name = "escr20-bronze", layer = "bronze", transition_ia = 90, transition_glacier = 365, expiration_days = 2555 }         # ingested raw data
  silver = { name = "escr20-silver", layer = "silver", transition_ia = 180, transition_glacier = 365, expiration_days = 2555 }        # curated/transformed data
}

# Glue catalog DBs. name gets a _<env> suffix; description is the AWS catalog description (ASCII only).
glue_databases = {
  raw    = { name = "escr20_raw", description = "Raw layer - unprocessed files from landing zone from external sources" }
  bronze = { name = "escr20_bronze", description = "Bronze layer - raw ingested data from all sources" }
  silver = { name = "escr20_silver", description = "Silver layer - curated and transformed data" }
}

airbyte_instance_type           = "m6g.2xlarge" # Airbyte ASG EC2 type; must be Graviton/arm64 to match the AMI; bigger = more sync throughput
airbyte_rds_instance_class      = "db.t3.small" # Airbyte config DB class; bigger handles more connections/metadata
airbyte_log_retention_days      = 30            # Days CloudWatch keeps Airbyte logs; higher = more storage cost
airbyte_rds_multi_az            = true          # HA standby for the config DB; false saves cost but drops failover
airbyte_rds_skip_final_snapshot = false         # false takes a final snapshot on destroy; true risks data loss
airbyte_rds_deletion_protection = true          # Blocks accidental DB deletion; must be off before an intended destroy
airbyte_s3_force_destroy        = false         # false prevents TF from emptying/deleting the bucket; true allows it (dev only)

airbyte_alb_allowed_cidr_blocks = ["181.96.188.51/32", "38.46.246.237/32", "69.147.62.1/32"] # IPs allowed to reach the Airbyte ALB UI; empty locks everyone out (VPN off in prod)
vpn_available                   = false                                                      # No Client VPN in prod; true adds an Airbyte :8000 ingress from the VPN SG

lakeformation_admin_arns              = []                     # Extra LF admins beyond the TF role; SSO reserved roles are rejected here
lakeformation_de_role_arns            = []                     # DE SSO roles granted LF data perms; empty for first apply (prod role unknown)
lakeformation_de_database_permissions = ["DESCRIBE"]           # DB-level LF grant for DE; DROP intentionally omitted in prod
lakeformation_de_table_permissions    = ["SELECT", "DESCRIBE"] # Table-level LF grant for DE; read-only, no DROP in prod

# Glue crawlers (one per source). enabled=false defines but pauses the schedule; update_behavior=LOG avoids overwriting TF-managed tables.
glue_crawlers = {
  connect_20 = { s3_bucket_key = "raw", s3_prefix = "connect20/", database_key = "raw", table_prefix = "connect20_", schedule = "cron(0 3 * * ? *)", enabled = false }
  ascender   = { s3_bucket_key = "raw", s3_prefix = "ascender/", database_key = "raw", table_prefix = "ascender_", schedule = "cron(0 5 * * ? *)", enabled = false, csv_classifier = true, csv_delimiter = ",", update_behavior = "LOG" }
  tea        = { s3_bucket_key = "bronze", s3_prefix = "tea/", database_key = "bronze", table_prefix = "tea_", schedule = "cron(0 5 * * ? *)", enabled = false, csv_classifier = true, csv_delimiter = ",", update_behavior = "UPDATE_IN_DATABASE", exclusions = ["pdfs/**", "wide_tables/**", "other/**"], combine_compatible_schemas = false }
}

gdrive_tea_folder_id           = "0AC5xbBuRiUvXUk9PVA" # Google Drive TEA source folder ID synced into s3 raw/tea/
gdrive_sync_enabled            = false                 # false deploys the Lambda without the EventBridge schedule (manual runs only)
gdrive_sync_schedule           = "cron(0 2 * * ? *)"   # Sync cadence when enabled (daily 02:00 UTC)
gdrive_sync_timeout            = 900                   # Lambda timeout seconds (max 900); raise for larger folders
gdrive_sync_memory             = 512                   # Lambda memory MB; higher also raises CPU/network
gdrive_sync_log_retention_days = 30                    # Days CloudWatch keeps the sync Lambda logs

# TEA Bronze Router Lambda
tea_bronze_router_timeout            = 900
tea_bronze_router_memory             = 256
tea_bronze_router_log_retention_days = 30

# TEA Schema Enforcer Lambda
tea_schema_enforcer_log_retention_days = 30
