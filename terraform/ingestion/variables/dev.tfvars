create       = true
environment  = "dev"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "784590287037"
#All Buckets Configuration in DEV
buckets = {
  raw = {
    name               = "escr20-landing-zone-raw"
    layer              = "raw"
    transition_ia      = 90
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
  bronze = {
    name        = "escr20-bronze"
    description = "Bronze layer — raw ingested data from all sources"
  }
  silver = {
    name        = "escr20-silver"
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