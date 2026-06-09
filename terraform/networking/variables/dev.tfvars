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

enable_flow_logs = true

# ---------------------------------------------------------------------------
# Client VPN
# ---------------------------------------------------------------------------
enable_client_vpn = true

# REQUIRED: Replace with the CIDR block to assign to VPN clients before applying.
client_vpn_client_cidr = "10.200.0.0/22"

# REQUIRED: Replace with the ACM certificate ARN for the VPN server certificate before applying.
client_vpn_server_certificate_arn = "arn:aws:acm:us-east-1:784590287037:certificate/ef55ad82-adc5-4d1d-bc0d-717cf674ed93"

