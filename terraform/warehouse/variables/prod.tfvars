create       = true           # Provision this stack's resources; false soft-deletes them while keeping state/code
environment  = "prod"         # Deployment env; drives resource names, TF workspace, and VPC/bucket lookups
aws_region   = "us-east-1"    # Target region; changing it relocates every resource
team         = "devops"       # Owning team; applied as a tag only
company_name = "region-20"    # Name prefix for resources and shared-resource tag lookups
account_id   = "029750300494" # Target AWS account; builds the cross-account assume-role ARN

# IAM principals allowed to use the Redshift KMS CMK. Empty for first apply - prod SSO role ARNs
# not yet known; account root and the Redshift service role keep access regardless.
redshift_key_users = [] # IAM role ARNs granted kms:Decrypt on the Redshift CMK; empty for first apply (prod SSO ARNs not yet known)

# S3 bucket ARNs the Redshift role may read via Spectrum/COPY; raising this widens read scope
data_lake_bucket_arns = ["arn:aws:s3:::escr20-bronze-prod", "arn:aws:s3:::escr20-silver-prod"] # S3 bucket ARNs the Redshift role may read via Spectrum/COPY; raising this widens read scope

redshift_max_capacity       = 64 # Max RPU ceiling; raising it lifts the cost cap and allows bigger query bursts
redshift_log_retention_days = 30 # Days CloudWatch keeps Redshift logs; higher = more retention and storage cost

# Athena query-results bucket + lifecycle (days before tiering/deletion).
athena_results = {
  name               = "escr20-athena-results-prod" # Results bucket name (globally unique)
  layer              = "athena"                     # Tag value only
  transition_ia      = 30                           # Days before STANDARD_IA (must be >= 30)
  transition_glacier = 60                           # Days before GLACIER (must be > transition_ia)
  expiration_days    = 90                           # Days before permanent delete (must be > transition_glacier)
}

glue_bronze_db_name = "escr20_bronze_prod" # Glue bronze DB for the Spectrum external schema; must match ingestion
glue_silver_db_name = "escr20_silver_prod" # Glue silver DB for the Spectrum external schema; must match ingestion

dbt_redshift_user  = "dbt_service"             # Passwordless IAM-brokered Redshift user (kept for reference; actual connecting user is IAMR:<dbt_task_role_name>)
dbt_task_role_name = "region-20-prod-dbt-task" # ECS task IAM role; Redshift Serverless GetCredentials maps this to IAMR:region-20-prod-dbt-task

vpn_enabled = false # No Client VPN in prod; true adds a Redshift :5439 ingress from the VPN SG (and requires it to exist)
