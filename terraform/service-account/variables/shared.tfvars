create       = true
environment  = "shared"
aws_region   = "us-east-1"
company_name = "region-20"
team         = "platform"

ecr_image_retention_count = 10

# Workload accounts permitted to pull the shared dbt Core image (dev, prod).
consumer_account_ids = [
  "784590287037",
  "029750300494",
]
