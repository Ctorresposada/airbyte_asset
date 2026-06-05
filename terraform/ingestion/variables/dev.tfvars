create           = true
environment      = "dev"
aws_region       = "us-east-1"
team             = "devops"
company_name     = "region-20"
account_id       = "784590287037"
oci_bastion_host = "129.146.105.89/32"
#All Buckets Configuration in DEV
buckets = {
  raw = {
    name               = "escr20-landing-zone-raw"
    layer              = "raw"
    transition_ia      = 100
    transition_glacier = 365
    expiration_days    = 2555
  }
  bronze = {
    name               = "escr20-bronze"
    layer              = "bronze"
    transition_ia      = 90
    transition_glacier = 365
    expiration_days    = 2555
  }
  silver = {
    name               = "escr20-silver"
    layer              = "silver"
    transition_ia      = 180
    transition_glacier = 365
    expiration_days    = 2555
  }
}
#All Glue Databases Configuration in DEV
glue_databases = {
  raw = {
    name        = "escr20_raw"
    description = "Raw layer — unprocessed files from landing zone from external sources"
  }
  bronze = {
    name        = "escr20_bronze"
    description = "Bronze layer — raw ingested data from all sources"
  }
  silver = {
    name        = "escr20_silver"
    description = "Silver layer — curated and transformed data"
  }
}

# Airbyte compute -- dev cost optimization
airbyte_instance_type           = "m6a.xlarge"
airbyte_rds_instance_class      = "db.t3.micro"
airbyte_log_retention_days      = 30
airbyte_rds_multi_az            = false
airbyte_rds_skip_final_snapshot = true
airbyte_rds_deletion_protection = false
airbyte_s3_force_destroy        = true

airbyte_alb_allowed_cidr_blocks = ["10.200.0.0/22"]
vpn_available                   = true

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
lakeformation_admin_arns = []

# DE role: ARN without region segment (SSO reserved role path).
lakeformation_de_role_arns = [
  "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8",
]

# DEV ONLY — DROP allows the team to clean up test databases and tables during development.
# Remove DROP from both variables (keep DESCRIBE / SELECT + DESCRIBE only) when adding stg/prod tfvars.
lakeformation_de_database_permissions = ["DESCRIBE", "DROP"]
lakeformation_de_table_permissions    = ["SELECT", "DESCRIBE", "DROP"]

glue_crawlers = {
  connect_20 = {
    s3_bucket_key = "raw"
    s3_prefix     = "connect20/"
    database_key  = "raw"
    table_prefix  = "connect20_"
    schedule      = "cron(0 3 * * ? *)" # 9 PM CST / 3 AM UTC
    enabled       = false               # if set to false, it pauses schedule, crawler still exists but won't run automatically
  }
  ascender = {
    s3_bucket_key  = "raw"
    s3_prefix      = "ascender/"
    database_key   = "raw"
    table_prefix   = "ascender_"
    schedule       = "cron(0 5 * * ? *)" # 11 PM CST / 5 AM UTC
    enabled        = false
    csv_classifier = true # CSV files contain quoted fields with commas — uses OpenCSVSerDe
    csv_delimiter  = ","
  }
}

# ---------------------------------------------------------------------------
# Google Drive → S3 raw sync (Lambda)
# ---------------------------------------------------------------------------
# gdrive_tea_folder_id: already known — hardcoded in gdrive_to_s3.py as default
gdrive_tea_folder_id = "0AC5xbBuRiUvXUk9PVA"

gdrive_sync_enabled            = true
gdrive_sync_schedule           = "cron(0 2 * * ? *)" # daily 02:00 UTC
gdrive_sync_timeout            = 900
gdrive_sync_memory             = 512
gdrive_sync_log_retention_days = 30
