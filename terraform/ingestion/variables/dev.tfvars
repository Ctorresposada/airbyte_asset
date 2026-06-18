create           = true                # Provision resources; false soft-deletes while keeping state
environment      = "dev"               # Deployment env; drives names, workspace, and -dev bucket/DB suffixes
aws_region       = "us-east-1"         # Target region; changing it relocates all resources
team             = "devops"            # Owning team tag
company_name     = "region-20"         # Name prefix and shared-resource tag lookups
account_id       = "784590287037"      # Target AWS account (dev); builds the cross-account assume-role ARN
oci_bastion_host = "129.146.105.89/32" # OCI bastion CIDR; Airbyte SG egress :22 target for the Oracle source
tas_bastion_host = "69.147.58.13/32"   # TAS bastion CIDE, Airbyte SG egress :22 for the MSSQL source
#All Buckets Configuration in DEV
# S3 layer buckets. name gets a -<env> suffix; transition_*/expiration_days set the lifecycle (days).
buckets = {
  raw = {
    name               = "escr20-landing-zone-raw" # landing zone for all sources
    layer              = "raw"                     # Tag value only
    transition_ia      = 100                       # Days before STANDARD_IA
    transition_glacier = 365                       # Days before GLACIER
    expiration_days    = 2555                      # Days before permanent delete (~7 years)
  }
  bronze = {
    name               = "escr20-bronze" # ingested raw data
    layer              = "bronze"        # Tag value only
    transition_ia      = 90              # Days before STANDARD_IA
    transition_glacier = 365             # Days before GLACIER
    expiration_days    = 2555            # Days before permanent delete (~7 years)
  }
  silver = {
    name               = "escr20-silver" # curated/transformed data
    layer              = "silver"        # Tag value only
    transition_ia      = 180             # Days before STANDARD_IA
    transition_glacier = 365             # Days before GLACIER
    expiration_days    = 2555            # Days before permanent delete (~7 years)
  }
}
#All Glue Databases Configuration in DEV
# Glue catalog DBs. name gets a _<env> suffix; description is the AWS catalog description.
glue_databases = {
  raw = {
    name        = "escr20_raw" # Glue raw layer DB
    description = "Raw layer — unprocessed files from landing zone from external sources"
  }
  bronze = {
    name        = "escr20_bronze" # Glue bronze layer DB
    description = "Bronze layer — raw ingested data from all sources"
  }
  silver = {
    name        = "escr20_silver" # Glue silver layer DB
    description = "Silver layer — curated and transformed data"
  }
}

# Airbyte compute -- dev cost optimization
airbyte_instance_type           = "m6g.2xlarge" # Airbyte ASG EC2 type; Graviton/arm64 to match the AMI; bigger = more sync throughput
airbyte_rds_instance_class      = "db.t3.micro" # Airbyte config DB class; smallest class, dev cost optimization
airbyte_log_retention_days      = 30            # Days CloudWatch keeps Airbyte logs; higher = more storage cost
airbyte_rds_multi_az            = false         # HA off in dev for cost; true adds a standby with automatic failover
airbyte_rds_skip_final_snapshot = true          # dev: skip final snapshot on destroy (no data to preserve)
airbyte_rds_deletion_protection = false         # dev: deletion protection off so the env can be torn down
airbyte_s3_force_destroy        = true          # dev only: allows TF to empty/destroy the bucket

# Populate with external IP CIDRs to allow access to the Airbyte ALB (e.g., ["1.2.3.4/32"]) - ctorres IP added 2026-06-09
airbyte_alb_allowed_cidr_blocks = ["181.96.188.51/32", "38.46.246.237/32", "69.147.62.1/32", "190.53.0.160/32", "177.170.246.23/32", "189.6.208.52/32", "38.46.246.239/32"] # IPs allowed to reach the Airbyte ALB UI
vpn_available                   = true                                                                                                                                      # Adds an Airbyte :8000 ingress from the VPN SG (VPN active in dev)

# Lake Formation: lakeformation_admin_arns intentionally empty.
# SSO reserved roles (/aws-reserved/sso.amazonaws.com/) are rejected by PutDataLakeSettings.
#
# MANUAL STEP REQUIRED (Identity Center management account):
#   Add lakeformation:GetDataAccess (Resource: *) to the following SSO permission sets
#   so their roles can call LF-vended credentials via Athena:
#     - DataEngineer  (AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8)
#     - Analyst       (permission set not yet created — see TECH DEBT below)
#     - Auditor       (permission set not yet created — see TECH DEBT below)
#
# TECH DEBT: Analyst and Auditor SSO permission sets do not exist in Identity Center yet
# (confirmed via aws iam list-roles --path-prefix /aws-reserved/sso.amazonaws.com/ on 2026-05-25).
lakeformation_admin_arns = [] # Extra LF admins beyond the TF role; SSO reserved roles are rejected here

# DE role: ARN without region segment (SSO reserved role path). Dev account DE SSO role.
lakeformation_de_role_arns = [
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8",
]

# allows DBT to access data lake
lakeformation_dbt_task_role_arns = [
  "arn:aws:iam::784590287037:role/region-20-dev-dbt-task",
]

# DEV ONLY — DROP allows the team to clean up test databases and tables during development.
# Remove DROP from both variables (keep DESCRIBE / SELECT + DESCRIBE only) when adding stg/prod tfvars.
lakeformation_de_database_permissions = ["DESCRIBE", "DROP"]           # DB-level LF grant for DE; DROP is DEV ONLY for test cleanup; removed in prod
lakeformation_de_table_permissions    = ["SELECT", "DESCRIBE", "DROP"] # Table-level LF grant for DE; DROP is DEV ONLY for test cleanup; removed in prod

# Glue crawlers (one per source). enabled=false defines but pauses the schedule; update_behavior=LOG avoids overwriting TF-managed tables.
glue_crawlers = {
  connect_20 = {                        #parquet file
    s3_bucket_key = "raw"               # which buckets key to crawl
    s3_prefix     = "connect20/"        # key prefix within the bucket
    database_key  = "raw"               # target Glue DB (glue_databases key)
    table_prefix  = "connect20_"        # prefix added to discovered table names
    schedule      = "cron(0 3 * * ? *)" # 9 PM CST / 3 AM UTC
    enabled       = false               # if set to false, it pauses schedule, crawler still exists but won't run automatically
  }
  ascender = {                            #CSV file
    s3_bucket_key   = "raw"               # which buckets key to crawl
    s3_prefix       = "ascender/"         # key prefix within the bucket
    database_key    = "raw"               # target Glue DB (glue_databases key)
    table_prefix    = "ascender_"         # prefix added to discovered table names
    schedule        = "cron(0 5 * * ? *)" # 11 PM CST / 5 AM UTC
    enabled         = false               # if set to false, it pauses schedule, crawler still exists but won't run automatically
    csv_classifier  = true                # CSV files contain quoted fields with commas — uses OpenCSVSerDe
    csv_delimiter   = ","                 # field delimiter for the CSV classifier
    update_behavior = "LOG"               # prevents crawler from overwriting the Terraform-managed ascender_invoice table
  }
  tea = { # CSV files from TEA — crawls bronze subfolders, one table per folder
    s3_bucket_key              = "bronze"
    s3_prefix                  = "tea/"
    database_key               = "bronze"
    table_prefix               = "tea_"
    schedule                   = "cron(0 5 * * ? *)" # 11 PM CST / 5 AM UTC — after gdrive sync and router Lambda
    enabled                    = true
    csv_classifier             = true
    csv_delimiter              = ","
    update_behavior            = "UPDATE_IN_DATABASE"
    exclusions                 = ["pdfs/**", "wide_tables/**", "other/**"]
    combine_compatible_schemas = false # each subfolder = one table; disable cross-folder schema merging
  }
}

# ---------------------------------------------------------------------------
# Google Drive → S3 raw sync (Lambda)
# ---------------------------------------------------------------------------
# gdrive_tea_folder_id: already known — hardcoded in gdrive_to_s3.py as default
gdrive_tea_folder_id = "0AC5xbBuRiUvXUk9PVA" # Google Drive TEA source folder ID synced into s3 raw/tea/

gdrive_sync_enabled            = true                # EventBridge schedule active in dev; false = manual runs only
gdrive_sync_schedule           = "cron(0 2 * * ? *)" # daily 02:00 UTC
gdrive_sync_timeout            = 900                 # Lambda timeout seconds (max 900); raise for larger Google Drive folders, ex 900
gdrive_sync_memory             = 512                 # Lambda memory MB; higher also increases CPU and network bandwidth, ex 512
gdrive_sync_log_retention_days = 30                  # Days CloudWatch retains the sync Lambda logs, ex 30

# ---------------------------------------------------------------------------
# TEA Bronze Router Lambda
# ---------------------------------------------------------------------------
tea_bronze_router_timeout            = 900 # 15 min max — backfill of 100+ files needs time
tea_bronze_router_memory             = 512 # reads full CSVs into pandas for Parquet conversion
tea_bronze_router_log_retention_days = 30  # Days CloudWatch retains TEA router Lambda logs, ex 30

# ---------------------------------------------------------------------------
# PDF Extraction Lambda (raw → bronze)
# ---------------------------------------------------------------------------
# AWS-managed public layer for pandas + pyarrow (account 336392948345) / Free cost and memory
# Check latest version: https://github.com/aws/aws-sdk-pandas/releases
# Current: AWS SDK for pandas v3.16.1, Python 3.12, x86_64, us-east-1
pdf_extraction_pandas_layer_arn = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python312:27" # AWS SDK for pandas public Lambda layer ARN; update version after checking https://github.com/aws/aws-sdk-pandas/releases
