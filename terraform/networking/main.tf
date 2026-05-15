# Stack: networking
# Provisions VPC, subnets, NAT Gateways, VPC endpoints, and Flow Logs for one environment.

module "networking" {
  count  = var.create ? 1 : 0
  source = "../modules/networking"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  flow_log_bucket_arn = var.flow_log_bucket_arn

  enable_flow_logs                    = var.enable_flow_logs
  flow_log_traffic_type               = var.flow_log_traffic_type
  flow_log_file_format                = var.flow_log_file_format
  flow_log_hive_compatible_partitions = var.flow_log_hive_compatible_partitions
  flow_log_per_hour_partition         = var.flow_log_per_hour_partition
}
