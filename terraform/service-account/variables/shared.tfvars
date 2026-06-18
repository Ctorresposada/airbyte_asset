create       = true        # Master toggle; false soft-deletes all resources while keeping state, ex true
environment  = "shared"    # Environment label for this shared services account, ex "shared"
aws_region   = "us-east-1" # Target AWS region for ECR and shared resources, ex "us-east-1"
company_name = "region-20" # Resource name prefix used for ECR repository naming, ex "region-20"
team         = "platform"  # Owning team tag; platform team manages shared services, ex "platform"

ecr_image_retention_count = 10 # Max tagged images retained per ECR repository; older images are pruned automatically on push, ex 10

# Workload accounts permitted to pull the shared dbt Core image (dev, prod).
consumer_account_ids = [
  "784590287037",
  "029750300494",
]
