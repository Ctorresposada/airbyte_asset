create       = true           # Master toggle; false soft-deletes all resources while preserving state, ex true
environment  = "dev"          # Deployment environment; drives resource names, TF workspace, and VPC CIDR tier, ex "dev"
aws_region   = "us-east-1"    # Target AWS region; changing it relocates all resources, ex "us-east-1"
team         = "devops"       # Owning team tag applied to all resources, ex "devops"
company_name = "region-20"    # Resource name prefix used across all stacks, ex "region-20"
account_id   = "784590287037" # Target AWS account ID (dev); used in cross-account role ARN construction, ex "784590287037"

vpc_cidr             = "172.17.0.0/16"                                        # CIDR block for the VPC; determines the private IP address space, ex "172.17.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]             # Availability zones to span; drives subnet, NAT Gateway, and VPN distribution, ex ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["172.17.0.0/24", "172.17.1.0/24", "172.17.2.0/24"]    # CIDRs for public subnets (one per AZ, must be within vpc_cidr); hosts NAT Gateways and ALBs, ex ["172.17.0.0/24", "172.17.1.0/24", "172.17.2.0/24"]
private_subnet_cidrs = ["172.17.16.0/20", "172.17.32.0/20", "172.17.48.0/20"] # CIDRs for private subnets (one per AZ); workloads, Airbyte, and RDS instances live here, ex ["172.17.16.0/20", "172.17.32.0/20", "172.17.48.0/20"]

single_nat_gateway     = true  # Use one shared NAT Gateway for cost optimization; set false and one_nat_gateway_per_az=true for HA, ex true
one_nat_gateway_per_az = false # Deploy a NAT Gateway per AZ for high availability; mutually exclusive with single_nat_gateway, ex false

flow_log_bucket_arn = "arn:aws:s3:::region-20-audit-vpc-flow-logs" # ARN of the centralized audit S3 bucket receiving VPC flow logs (created by audit stack), ex "arn:aws:s3:::region-20-audit-vpc-flow-logs"

enable_flow_logs = true # Enable VPC flow log delivery to the audit bucket; required for security compliance, ex true

# ---------------------------------------------------------------------------
# Client VPN
# ---------------------------------------------------------------------------
enable_client_vpn = true # Deploy an AWS Client VPN endpoint for private access to Airbyte and Redshift; requires certificate and SAML metadata, ex true

# REQUIRED: Replace with the CIDR block to assign to VPN clients before applying.
client_vpn_client_cidr = "10.200.0.0/22" # CIDR assigned to VPN-connected clients; must not overlap the VPC or on-prem CIDRs (/22 minimum), ex "10.200.0.0/22"

# REQUIRED: Replace with the ACM certificate ARN for the VPN server certificate before applying.
client_vpn_server_certificate_arn = "arn:aws:acm:us-east-1:784590287037:certificate/ef55ad82-adc5-4d1d-bc0d-717cf674ed93" # ACM certificate ARN for the VPN server TLS identity; must exist in the same region as the VPC, ex "arn:aws:acm:us-east-1:..."
