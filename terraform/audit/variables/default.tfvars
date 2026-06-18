environment  = "shared"       # Environment identifier for this dedicated audit account, ex "shared"
aws_region   = "us-east-1"    # Target AWS region; changing it relocates all resources, ex "us-east-1"
team         = "devops"       # Owning team tag applied to all resources, ex "devops"
company_name = "region-20"    # Resource name prefix, ex "region-20"
account_id   = "627896767065" # AWS account ID for the dedicated centralized audit account, ex "627896767065"

flow_log_bucket_name = "region-20-audit-vpc-flow-logs" # S3 bucket name receiving VPC flow logs from all source accounts, ex "region-20-audit-vpc-flow-logs"

# Workload account IDs allowed to write flow logs to the bucket; add new accounts here, ex ["784590287037", "029750300494"]
source_account_ids = [
  "784590287037", # dev
  "029750300494", # prod
]

flow_log_retention_days       = 365   # Days before S3 objects expire; 365 meets common compliance baselines, ex 365
flow_log_bucket_force_destroy = false # Allow TF to destroy a non-empty bucket; set false in production, ex false
