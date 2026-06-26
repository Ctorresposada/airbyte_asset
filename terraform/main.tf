# Airbyte Asset — Root Module
# Deploys a fully functional self-hosted Airbyte console into any AWS account.
# Requires an existing VPC with public and private subnets.

# ---------------------------------------------------------------------------
# Data sources -- AMI lookup
# ---------------------------------------------------------------------------

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.ami_architecture}"
}

# ---------------------------------------------------------------------------
# Airbyte module
# ---------------------------------------------------------------------------

module "airbyte" {
  source = "./modules/airbyte"

  name               = "${var.project_name}-${var.environment}"
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  ami_id             = data.aws_ssm_parameter.al2023_ami.value

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
