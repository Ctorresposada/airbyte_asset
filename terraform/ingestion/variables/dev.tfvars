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