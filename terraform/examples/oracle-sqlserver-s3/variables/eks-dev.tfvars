# Example: Oracle + SQL Server → S3 Data Lake
# EKS deployment variant — Caylent Sandbox (931366402038)
#
# Update s3_access_key_id and s3_secret_access_key with your own IAM credentials
# before applying. All other values reflect the working Caylent sandbox setup.

# Airbyte API
# airbyte_server_url / airbyte_token_url: replace the domain with your airbyte_url Terraform output.
#
# airbyte_client_id / airbyte_client_secret: log into the Airbyte UI, then go to
#   Settings → Applications → Create new application.
#   Copy the client ID and secret from there — no kubectl needed.
#
# workspace_id: visible in the browser URL after logging in:
#   https://<your-domain>/workspaces/<workspace_id>/...
airbyte_server_url    = "https://airbyte-eks-dev.caylent-airbyte-asset.click/api/public/v1/"
airbyte_token_url     = "https://airbyte-eks-dev.caylent-airbyte-asset.click/api/v1/applications/token"
airbyte_client_id     = "cad98e91-c1a0-4eee-9200-aa2a095532b3"
airbyte_client_secret = "rFXb1aTIQhPySonUWjDTZWaG8GcSTVrq"
workspace_id          = "82fee0b6-7c10-4939-a01f-f0927e9da40f"

# AWS (source DBs and Secrets Manager are in eu-west-1)
aws_region  = "eu-west-1"
aws_profile = "AdminSandbox"

# Oracle source
oracle_host                = "oracle-source-db.cn9ujway9hb1.eu-west-1.rds.amazonaws.com"
oracle_port                = 1521
oracle_service_name        = "ORCL"
oracle_username            = "admin"
oracle_password_secret_arn = "arn:aws:secretsmanager:eu-west-1:931366402038:secret:rds!db-d268fbac-36e1-46b2-bd9f-0ac3bd5d8287-cBroiA"
oracle_schemas             = ["TEST"]

# SQL Server source
mssql_host                = "sqlserver-source-db.cn9ujway9hb1.eu-west-1.rds.amazonaws.com"
mssql_port                = 1433
mssql_database            = "SourceDB"
mssql_username            = "admin"
mssql_password_secret_arn = "arn:aws:secretsmanager:eu-west-1:931366402038:secret:rds!db-8be95ef6-9107-41b6-b574-ad913e7a1652-tO3rkz"
mssql_schemas             = ["dbo"]

# S3 Data Lake destination (Iceberg + Glue Catalog)
# Replace s3_access_key_id and s3_secret_access_key with your own IAM credentials.
s3_bucket_name        = "ctorres-rg20-bronzetest"
s3_bucket_region      = "eu-west-1"
s3_warehouse_location = "s3://ctorres-rg20-bronzetest/iceberg/"
s3_access_key_id      = "YOUR_AWS_ACCESS_KEY_ID"
s3_secret_access_key  = "YOUR_AWS_SECRET_ACCESS_KEY"
glue_database         = "airbyte_asset_catalog"
glue_account_id       = "931366402038"
