# Example: Dev environment
# Copy this file and adjust values for your deployment.

aws_region   = "us-east-1"
project_name = "my-company-airbyte"
environment  = "dev"

# Networking -- replace with your VPC and subnet IDs
vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids = ["subnet-aaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbb"]
public_subnet_ids  = ["subnet-ccccccccccccc", "subnet-ddddddddddddd"]

# DNS (optional) -- set these for a custom domain with auto-provisioned certificate
# domain_name     = "airbyte-dev.example.com"
# route53_zone_id = "Z0123456789ABCDEFGHIJ"

# EC2
instance_type   = "m6g.xlarge"
ebs_volume_size = 50

# RDS
rds_instance_class      = "db.t3.micro"
rds_multi_az            = false
rds_skip_final_snapshot = true
rds_deletion_protection = false

# Operations
log_retention_days = 30
s3_force_destroy   = true

tags = {
  Team = "data-engineering"
}
