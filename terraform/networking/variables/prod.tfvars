create       = true
environment  = "prod"
aws_region   = "us-east-1"
team         = "devops"
company_name = "region-20"
account_id   = "029750300494"

vpc_cidr             = "172.18.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["172.18.0.0/24", "172.18.1.0/24", "172.18.2.0/24"]
private_subnet_cidrs = ["172.18.16.0/20", "172.18.32.0/20", "172.18.48.0/20"]

single_nat_gateway     = false
one_nat_gateway_per_az = true

flow_log_bucket_arn = "arn:aws:s3:::region-20-audit-vpc-flow-logs"

enable_flow_logs                    = true
flow_log_traffic_type               = "REJECT"
flow_log_file_format                = "parquet"
flow_log_hive_compatible_partitions = true
flow_log_per_hour_partition         = true
