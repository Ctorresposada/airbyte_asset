# Bastion host for dbt Cloud -> Redshift Serverless SSH tunnel — R2EP2IC-111
#
# Key pair workflow: dbt Cloud generates its own SSH key pair and provides the
# public key during connection setup. Add that public key to the instance via
# SSM Session Manager (see docs/runbook-bastion.md). No key pair is managed
# by Terraform; the instance is administered exclusively through SSM.

# ----------------------------------------------------------------------------
# IAM role and instance profile
# ----------------------------------------------------------------------------

resource "aws_iam_role" "bastion" {
  count = var.create ? 1 : 0

  name = "${local.name}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
  count = var.create ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "bastion_secrets" {
  count = var.create ? 1 : 0

  name = "${local.name}-bastion-secrets"
  role = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KmsDecryptForCWAgentAndEBS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = module.bastion_kms[0].key_arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.create ? 1 : 0

  name = "${local.name}-bastion"
  role = aws_iam_role.bastion[0].name
}

# ----------------------------------------------------------------------------
# EC2 instance
# ----------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  #checkov:skip=CKV_AWS_126: Detailed monitoring not required for a low-traffic bastion; basic 5-minute monitoring is sufficient.
  #checkov:skip=CKV_AWS_8: User data does not contain secrets; SSH hardening script is safe to store in state.
  count = var.create ? 1 : 0

  ami                         = data.aws_ami.al2023[0].id
  instance_type               = var.bastion_instance_type
  ebs_optimized               = true
  subnet_id                   = data.aws_subnets.public[0].ids[0]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].name
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = module.bastion_kms[0].key_arn
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/bastion_user_data.sh.tpl", {
    log_group_auth             = "/aws/ec2/${local.name}-bastion/auth"
    bastion_log_retention_days = var.bastion_log_retention_days
  })

  tags = {
    Name = "${local.name}-bastion"
  }

  depends_on = [
    aws_cloudwatch_log_group.bastion_auth[0],
    aws_cloudwatch_log_group.bastion_metrics[0],
  ]
}

# ----------------------------------------------------------------------------
# Elastic IP
# ----------------------------------------------------------------------------

resource "aws_eip" "bastion" {
  #checkov:skip=CKV2_AWS_19: EIP is immediately associated with the bastion instance via aws_eip_association below.
  count = var.create ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${local.name}-bastion"
  }
}

resource "aws_eip_association" "bastion" {
  count = var.create ? 1 : 0

  instance_id   = aws_instance.bastion[0].id
  allocation_id = aws_eip.bastion[0].id
}
