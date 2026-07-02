# Module: airbyte-eks — EKS cluster, node group, add-ons, and Helm releases
#
# Deployment order (Terraform handles this via depends_on):
#   1. EKS cluster
#   2. OIDC provider + IRSA roles (see iam.tf — depend on cluster)
#   3. Node group (depends on cluster + IAM)
#   4. EKS add-ons (depends on node group)
#   5. ALB controller Helm release (depends on add-ons)
#   6. Airbyte + ExternalDNS Helm releases (depend on ALB controller)
#
# NOTE: EKS deployments require TWO terraform apply passes due to a Terraform
# provider limitation — the kubernetes/helm providers are configured from the
# cluster endpoint output, which is unknown during the first apply:
#   Pass 1: terraform apply          (creates cluster, IAM, RDS, S3, node group)
#   Pass 2: terraform apply          (installs add-ons and Helm charts)

# ---------------------------------------------------------------------------
# EKS cluster
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_public_access_cidrs
    security_group_ids      = [] # EKS manages its own cluster security group
  }

  # Encrypt Kubernetes secrets at rest with the CMK.
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.this.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  #checkov:skip=CKV_AWS_39: Public endpoint enabled intentionally for demo/CoE use; set endpoint_public_access=false and public_access_cidrs for production
  #checkov:skip=CKV_AWS_58: Secrets encryption enabled via encryption_config block above
  #checkov:skip=CKV_AWS_37: All control plane log types enabled via enabled_cluster_log_types
  #checkov:skip=CKV_AWS_38: Private access is enabled (endpoint_private_access = true)
}

# ---------------------------------------------------------------------------
# KMS propagation wait
# AWS KMS keys can take a few seconds to become fully usable after creation.
# Without this wait, EC2 may attempt to use the key for EBS encryption before
# it has propagated, causing an InvalidKMSKey.InvalidState error in the node group.
# ---------------------------------------------------------------------------

resource "time_sleep" "kms_propagation" {
  depends_on      = [aws_kms_key.this, aws_kms_alias.this]
  create_duration = "15s"
}

# ---------------------------------------------------------------------------
# Node group launch template
# Encrypted EBS, IMDSv2, detailed monitoring, and dual security groups
# (cluster-managed SG + our application SG).
# ---------------------------------------------------------------------------

resource "aws_launch_template" "node" {
  name_prefix = "${local.name_prefix}-node-"
  description = "Launch template for Airbyte EKS node group (${var.name})"

  # Security groups: EKS cluster SG (for control-plane <-> node comms) +
  # our node_group SG (for ALB -> pod traffic and RDS egress).
  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.node_group.id,
  ]

  # IMDSv2 required. hop_limit=2 allows pods to reach IMDS for IRSA token exchange.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.this.arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-node-root" })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [time_sleep.kms_propagation]

  #checkov:skip=CKV_AWS_88: Nodes are in private subnets; no public IP association needed
  #checkov:skip=CKV_AWS_341: hop_limit=2 required for IRSA token exchange from pods
}

# ---------------------------------------------------------------------------
# EKS managed node group
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ---------------------------------------------------------------------------
# EKS add-ons
# Versions are resolved dynamically to the latest default for the cluster
# version, avoiding hardcoded version strings that drift over time.
# ---------------------------------------------------------------------------

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = aws_iam_role.irsa_ebs_csi.arn

  tags       = local.common_tags
  depends_on = [aws_eks_node_group.this]
}

# ---------------------------------------------------------------------------
# Helm: AWS Load Balancer Controller
# Provisions and manages ALBs from Kubernetes Ingress annotations.
# ---------------------------------------------------------------------------

resource "helm_release" "alb_controller" {
  count      = var.helm_enabled ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.12.0"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.irsa_alb_controller.arn
  }

  # Disable the default cert-manager webhook dependency for simplicity.
  set {
    name  = "enableCertManager"
    value = "false"
  }

  depends_on = [
    aws_eks_addon.coredns,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}

# ---------------------------------------------------------------------------
# Helm: ExternalDNS
# Watches Ingress resources and automatically manages Route53 records.
# Only deployed when route53_zone_id is provided.
# ---------------------------------------------------------------------------

resource "helm_release" "external_dns" {
  count = var.helm_enabled && local.create_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.16.1"
  namespace  = "external-dns"

  create_namespace = true

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = data.aws_region.current.region
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.irsa_external_dns.arn
  }

  set {
    name  = "zoneIdFilters[0]"
    value = var.route53_zone_id
  }

  set {
    name  = "txtOwnerId"
    value = var.name
  }

  set {
    name  = "policy"
    value = "sync"
  }

  depends_on = [helm_release.alb_controller[0]]
}

# ---------------------------------------------------------------------------
# Helm: Airbyte
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Pre-destroy: remove the Airbyte Ingress before Helm uninstall
# The ALB controller creates the ALB outside Terraform state. Deleting the
# Ingress first lets the controller clean up the ALB and its ENIs before
# the node security group is destroyed, preventing a DependencyViolation.
# ---------------------------------------------------------------------------

resource "null_resource" "delete_ingress_before_destroy" {
  count = var.helm_enabled ? 1 : 0

  triggers = {
    cluster_name = aws_eks_cluster.this.name
    region       = data.aws_region.current.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} 2>/dev/null || true
      kubectl delete ingress -n airbyte --all --ignore-not-found=true 2>/dev/null || true
      sleep 30
    EOT
  }

  depends_on = [helm_release.airbyte]
}

resource "helm_release" "airbyte" {
  count            = var.helm_enabled ? 1 : 0
  name             = "airbyte"
  repository       = "https://airbytehq.github.io/helm-charts"
  chart            = "airbyte"
  version          = var.airbyte_chart_version
  namespace        = "airbyte"
  create_namespace = true
  wait             = true
  timeout          = 1200 # Airbyte takes 7-15 minutes to fully initialize

  values = [templatefile("${path.module}/templates/airbyte-values.yaml.tpl", {
    db_host = aws_db_instance.this.address
    db_port = aws_db_instance.this.port
    db_name = var.rds_db_name
    db_user = var.rds_username

    temporal_db_host = aws_db_instance.this.address
    temporal_db_port = aws_db_instance.this.port
    temporal_db_name = var.rds_temporal_db_name
    temporal_db_user = var.rds_username

    s3_bucket_name      = aws_s3_bucket.this.id
    s3_region           = data.aws_region.current.region
    airbyte_url         = local.airbyte_url
    domain_name         = var.domain_name
    irsa_role_arn       = aws_iam_role.irsa_airbyte.arn
    certificate_arn     = local.effective_certificate_arn
    name                = var.name
    allowed_cidr_blocks = join(",", var.allowed_cidr_blocks)
    public_subnet_ids   = join(",", var.public_subnet_ids)
  })]

  # Inject database passwords via set_sensitive so they never appear in plan
  # output or unencrypted state values.
  set_sensitive {
    name  = "global.database.password"
    value = random_password.rds.result
  }

  set_sensitive {
    name  = "temporal.database.password"
    value = random_password.rds.result
  }

  depends_on = [
    helm_release.alb_controller[0],
    aws_eks_addon.coredns,
    aws_eks_addon.ebs_csi,
    aws_db_instance.this,
    aws_s3_bucket.this,
  ]
}
