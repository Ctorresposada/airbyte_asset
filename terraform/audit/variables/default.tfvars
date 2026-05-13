environment  = "shared"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "627896767065"

flow_log_bucket_name = "region-20-audit-vpc-flow-logs"

source_account_ids = [
  "784590287037", # dev
  "029750300494", # prod
]

flow_log_retention_days       = 365
flow_log_bucket_force_destroy = false
