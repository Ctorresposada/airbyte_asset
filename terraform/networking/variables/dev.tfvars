create       = true
environment  = "dev"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "784590287037"

vpc_cidr             = "172.17.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["172.17.0.0/24", "172.17.1.0/24", "172.17.2.0/24"]
private_subnet_cidrs = ["172.17.16.0/20", "172.17.32.0/20", "172.17.48.0/20"]

single_nat_gateway     = true
one_nat_gateway_per_az = false

flow_log_bucket_arn = "arn:aws:s3:::region-20-audit-vpc-flow-logs"

enable_flow_logs = false
