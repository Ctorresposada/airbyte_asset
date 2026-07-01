# Airbyte Asset — Root Module
# Deploys a fully functional self-hosted Airbyte console into any AWS account.
# Requires an existing VPC with public and private subnets.

# ---------------------------------------------------------------------------
# Data sources -- AMI lookup (EC2 only)
# ---------------------------------------------------------------------------

data "aws_ssm_parameter" "al2023_ami" {
  count = var.deployment_type == "ec2" ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.ami_architecture}"
}

# ---------------------------------------------------------------------------
# Airbyte EC2 module
# ---------------------------------------------------------------------------

module "airbyte_ec2" {
  count  = var.deployment_type == "ec2" ? 1 : 0
  source = "./modules/airbyte-ec2"

  name               = "${var.project_name}-${var.environment}"
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  ami_id             = data.aws_ssm_parameter.al2023_ami[0].value

  # DNS & Certificate
  create_alb          = var.create_alb
  alb_subnet_ids      = var.public_subnet_ids
  alb_internal        = var.alb_internal
  alb_certificate_arn = var.alb_certificate_arn
  allowed_cidr_blocks = var.allowed_cidr_blocks
  domain_name         = var.domain_name
  route53_zone_id     = var.route53_zone_id

  # EC2
  instance_type   = var.instance_type
  ebs_volume_size = var.ebs_volume_size

  # RDS
  rds_instance_class        = var.rds_instance_class
  rds_multi_az              = var.rds_multi_az
  rds_backup_retention_days = var.rds_backup_retention_days
  rds_deletion_protection   = var.rds_deletion_protection
  rds_skip_final_snapshot   = var.rds_skip_final_snapshot

  # Operations
  log_retention_days = var.log_retention_days
  s3_force_destroy   = var.s3_force_destroy

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Airbyte EKS module
# ---------------------------------------------------------------------------

module "airbyte_eks" {
  count  = var.deployment_type == "eks" ? 1 : 0
  source = "./modules/airbyte-eks"

  name               = "${var.project_name}-${var.environment}"
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids

  # DNS & Certificate
  alb_certificate_arn = var.alb_certificate_arn
  allowed_cidr_blocks = var.allowed_cidr_blocks
  domain_name         = var.domain_name
  route53_zone_id     = var.route53_zone_id

  # EKS
  helm_enabled          = var.eks_cluster_ready
  kubernetes_version    = var.eks_kubernetes_version
  node_instance_type    = var.eks_node_instance_type
  node_desired_size     = var.eks_node_desired_size
  node_min_size         = var.eks_node_min_size
  node_max_size         = var.eks_node_max_size
  airbyte_chart_version = var.eks_airbyte_chart_version

  # RDS
  rds_instance_class        = var.rds_instance_class
  rds_multi_az              = var.rds_multi_az
  rds_backup_retention_days = var.rds_backup_retention_days
  rds_deletion_protection   = var.rds_deletion_protection
  rds_skip_final_snapshot   = var.rds_skip_final_snapshot

  # Operations
  log_retention_days = var.log_retention_days
  s3_force_destroy   = var.s3_force_destroy

  tags = var.tags
}
