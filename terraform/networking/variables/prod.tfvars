create       = true           # Master toggle; false soft-deletes all resources while preserving state, ex true
environment  = "prod"         # Deployment environment; drives resource names, TF workspace, and VPC CIDR tier, ex "prod"
aws_region   = "us-east-1"    # Target AWS region; changing it relocates all resources, ex "us-east-1"
team         = "devops"       # Owning team tag applied to all resources, ex "devops"
company_name = "region-20"    # Resource name prefix used across all stacks, ex "region-20"
account_id   = "029750300494" # Target AWS account ID (prod); used in cross-account role ARN construction, ex "029750300494"

vpc_cidr             = "172.18.0.0/16"                                        # CIDR block for the VPC; determines the private IP address space, ex "172.18.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]             # Availability zones to span; drives subnet, NAT Gateway, and VPN distribution, ex ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["172.18.0.0/24", "172.18.1.0/24", "172.18.2.0/24"]    # CIDRs for public subnets (one per AZ, must be within vpc_cidr); hosts NAT Gateways and ALBs, ex ["172.18.0.0/24", "172.18.1.0/24", "172.18.2.0/24"]
private_subnet_cidrs = ["172.18.16.0/20", "172.18.32.0/20", "172.18.48.0/20"] # CIDRs for private subnets (one per AZ); workloads, Airbyte, and RDS instances live here, ex ["172.18.16.0/20", "172.18.32.0/20", "172.18.48.0/20"]

single_nat_gateway     = false # false: each AZ has its own NAT Gateway for high availability; raises cost vs single_nat_gateway=true, ex false
one_nat_gateway_per_az = true  # Deploy a NAT Gateway per AZ for HA; mutually exclusive with single_nat_gateway, ex true

flow_log_bucket_arn = "arn:aws:s3:::region-20-audit-vpc-flow-logs" # ARN of the centralized audit S3 bucket receiving VPC flow logs (created by audit stack), ex "arn:aws:s3:::region-20-audit-vpc-flow-logs"

enable_flow_logs                    = true      # Enable VPC flow log delivery to the audit bucket; required for security compliance, ex true
flow_log_traffic_type               = "REJECT"  # Traffic type to capture; REJECT logs only denied flows, reducing noise and storage cost in prod, ex "REJECT", allowed values: ACCEPT, REJECT, ALL
flow_log_file_format                = "parquet" # Log storage format; parquet reduces S3 size and enables direct Athena queries, ex "parquet", allowed values: plain-text, parquet
flow_log_hive_compatible_partitions = true      # Use Hive-style S3 key prefixes (year=/month=/day=/) for Athena partition auto-discovery, ex true
flow_log_per_hour_partition         = true      # Partition logs hourly rather than daily; reduces Athena scan size for short time-range queries, ex true

# ---------------------------------------------------------------------------
# Client VPN
# ---------------------------------------------------------------------------
enable_client_vpn = false # No Client VPN in prod yet; true would require server certificate and SAML IdP metadata, ex false

# REQUIRED: Replace with the CIDR block to assign to VPN clients before applying.
client_vpn_client_cidr = "10.201.0.0/22" # CIDR reserved for future VPN clients; must not overlap the VPC or on-prem CIDRs (/22 minimum), ex "10.201.0.0/22"

# REQUIRED: Replace with the ACM certificate ARN for the VPN server certificate before applying.
client_vpn_server_certificate_arn = "" # ACM certificate ARN for VPN server; empty = VPN not yet provisioned, ex "arn:aws:acm:us-east-1:..."

# client_vpn_saml_metadata_document is intentionally absent from tfvars.
# Pass it at plan/apply time via the environment variable:
#   export TF_VAR_client_vpn_saml_metadata_document="$(cat /path/to/metadata.xml)"
