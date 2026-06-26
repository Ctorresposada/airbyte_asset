# Dev environment — Caylent Sandbox (931366402038)

aws_region   = "us-east-1"
project_name = "airbyte-asset"
environment  = "dev"

# Networking — acevedo-test VPC
vpc_id = "vpc-08c247da1f721c193"

# Private subnets (EC2 + RDS — route through NAT)
private_subnet_ids = [
  "subnet-0b756c70d43048662", # us-east-1a
  "subnet-0da01bfc5f77dbbe6", # us-east-1b
  "subnet-07fc5b401ce922193"  # us-east-1c
]

# Public subnets (ALB — internet-facing)
public_subnet_ids = [
  "subnet-0c4b6767663a68e4b", # us-east-1a
  "subnet-0d3769ad3f92f964c", # us-east-1b
  "subnet-0a33c6f6c19da97b9"  # us-east-1c
]

# DNS — auto-provisions ACM certificate + Route53 A record
domain_name     = "airbyte-dev.caylent-airbyte-asset.click"
route53_zone_id = "Z0782528L7NFOYHOSU0L"

# EC2
instance_type   = "m6g.xlarge"
ebs_volume_size = 50
allowed_cidr_blocks = ["190.53.0.160/32"]
# RDS
rds_instance_class      = "db.t3.micro"
rds_multi_az            = false
rds_skip_final_snapshot = true
rds_deletion_protection = false

# Operations
log_retention_days = 30
s3_force_destroy   = true

tags = {
  Team  = "coe-data-modernization"
  Owner = "caylent:ctorres"
}
