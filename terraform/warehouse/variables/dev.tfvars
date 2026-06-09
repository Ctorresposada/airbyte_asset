create       = true           # Provision this stack's resources; false soft-deletes them while keeping state/code
environment  = "dev"          # Deployment env; drives resource names, TF workspace, and VPC/bucket lookups
aws_region   = "us-east-1"    # Target region; changing it relocates every resource
team         = "devops"       # Owning team; applied as a tag only
company_name = "region-20"    # Name prefix for resources and shared-resource tag lookups
account_id   = "784590287037" # Target AWS account (dev); builds the cross-account assume-role ARN

# IAM principals allowed to use the Redshift KMS CMK; these are the dev account SSO role ARNs.
redshift_key_users = ["arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_DataEngineer_Dev_cd1bbeb9335fcaa8", "arn:aws:iam::784590287037:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_9a7f3e7b3aa4c5bb"]

data_lake_bucket_arns       = ["arn:aws:s3:::escr20-bronze-dev", "arn:aws:s3:::escr20-silver-dev"] # S3 bucket ARNs the Redshift role may read via Spectrum/COPY; raising this widens read scope
redshift_max_capacity       = 32                                                                   # Max RPU ceiling (lower in dev to cap cost)
redshift_log_retention_days = 30                                                                   # Days CloudWatch keeps Redshift logs; higher = more retention and storage cost

#Athena configurations
athena_results = {
  name               = "escr20-athena-results-dev" # Results bucket name (globally unique)
  layer              = "athena"                    # Tag value only
  transition_ia      = 30                          # Days before STANDARD_IA (must be >= 30)
  transition_glacier = 60                          # Days before GLACIER (must be > transition_ia)
  expiration_days    = 90                          # Days before permanent delete (must be > transition_glacier)
}

bastion_instance_type      = "t3.micro" # Bastion EC2 type; only takes effect if enable_bastion=true (bastion disabled by default)
bastion_log_retention_days = 30         # Days CloudWatch keeps bastion logs; only takes effect if enable_bastion=true (bastion disabled by default)

# Glue Catalog database names — must match ingestion stack outputs (escr20_<layer>_<env>)
glue_bronze_db_name = "escr20_bronze_dev" # Glue bronze DB for the Spectrum external schema; must match ingestion
glue_silver_db_name = "escr20_silver_dev" # Glue silver DB for the Spectrum external schema; must match ingestion

# dbt Core service user (IAM-brokered, passwordless) created in redshift_schemas.tf
dbt_redshift_user = "dbt_service" # Passwordless IAM-brokered Redshift user dbt connects as

vpn_enabled = true # Adds a Redshift :5439 ingress from the Client VPN SG (VPN active in dev)

