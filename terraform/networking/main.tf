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
}
