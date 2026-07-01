# Module: airbyte-eks — IAM
# Four IAM roles:
#   1. rds_enhanced_monitoring — RDS enhanced monitoring (same as EC2 module)
#   2. node_group              — EKS managed node group (EC2 worker nodes)
#   3. cluster                 — EKS control plane
#   4. irsa_airbyte            — IRSA for Airbyte pods (replaces EC2 instance profile)
#   5. irsa_ebs_csi            — IRSA for EBS CSI driver add-on
#   6. irsa_alb_controller     — IRSA for AWS Load Balancer Controller
#   7. irsa_external_dns       — IRSA for ExternalDNS

# ---------------------------------------------------------------------------
# RDS enhanced monitoring role (identical to EC2 module)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${local.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# EKS cluster role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name_prefix}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# EKS node group role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "node_group_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node_group" {
  name               = "${local.name_prefix}-node-group"
  assume_role_policy = data.aws_iam_policy_document.node_group_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------------------------------------------------------------------------
# OIDC provider -- required for all IRSA roles
# ---------------------------------------------------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# IRSA helpers -- reusable locals for the OIDC issuer hostname
# ---------------------------------------------------------------------------

locals {
  oidc_issuer_host = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# ---------------------------------------------------------------------------
# IRSA -- Airbyte pods
# Replaces the EC2 instance profile. Grants S3, Secrets Manager, and KMS
# access scoped to the airbyte service account in the airbyte namespace.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_airbyte_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:airbyte:airbyte-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_airbyte" {
  name               = "${local.name_prefix}-irsa-airbyte"
  assume_role_policy = data.aws_iam_policy_document.irsa_airbyte_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "irsa_airbyte_policy" {
  # S3 access for Airbyte logs, state payloads, and workload output.
  statement {
    sid    = "AirbyteS3Objects"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObjectAcl",
      "s3:ListBucketMultipartUploads",
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid       = "AirbyteS3Bucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  # Secrets Manager: allow Airbyte to manage connector credentials under airbyte/ prefix.
  statement {
    sid    = "AirbyteSecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:CreateSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:TagResource",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:airbyte/*",
      aws_secretsmanager_secret.rds.arn,
      aws_secretsmanager_secret.airbyte_admin.arn,
    ]
  }

  # KMS: decrypt EBS volumes, S3 objects, and CloudWatch log group.
  statement {
    sid    = "AirbyteKms"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_role_policy" "irsa_airbyte" {
  name   = "${local.name_prefix}-irsa-airbyte-inline"
  role   = aws_iam_role.irsa_airbyte.id
  policy = data.aws_iam_policy_document.irsa_airbyte_policy.json
}

# ---------------------------------------------------------------------------
# IRSA -- EBS CSI driver
# Required for encrypting Kubernetes PersistentVolumes with the CMK.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_ebs_csi_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_ebs_csi" {
  name               = "${local.name_prefix}-irsa-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.irsa_ebs_csi_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "irsa_ebs_csi" {
  role       = aws_iam_role.irsa_ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ---------------------------------------------------------------------------
# IRSA -- AWS Load Balancer Controller
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_alb_controller_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_alb_controller" {
  name               = "${local.name_prefix}-irsa-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.irsa_alb_controller_assume.json

  tags = local.common_tags
}

# The ALB controller policy document is large and well-maintained by AWS.
# We inline the essential permissions here rather than fetching a remote policy URL.
data "aws_iam_policy_document" "irsa_alb_controller_policy" {
  statement {
    sid       = "CreateServiceLinkedRole"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  statement {
    sid    = "EC2ReadAccess"
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELBReadAccess"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeTrustStores",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CertificateReadAccess"
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CognitoReadAccess"
    effect    = "Allow"
    actions   = ["cognito-idp:DescribeUserPoolClient"]
    resources = ["*"]
  }

  statement {
    sid    = "WAFReadAccess"
    effect = "Allow"
    actions = [
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:ListResourcesForWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EC2SGWrite"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EC2TagWrite"
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = "EC2TagManage"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid       = "EC2SGDelete"
    effect    = "Allow"
    actions   = ["ec2:DeleteSecurityGroup"]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = "ELBWrite"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = "ELBListenerWrite"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELBTagWrite"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  # Allow AddTags on new resources at creation time (newly created target groups
  # and load balancers don't have the cluster tag yet, so ELBTagWrite above won't match).
  statement {
    sid     = "ELBTagWriteOnCreate"
    effect  = "Allow"
    actions = ["elasticloadbalancing:AddTags"]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values   = ["CreateTargetGroup", "CreateLoadBalancer"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = "ELBListenerTagWrite"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*",
    ]
  }

  statement {
    sid    = "ELBModify"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListenerAttributes",
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }

  statement {
    sid    = "ELBTargetWrite"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
    ]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }

  statement {
    sid    = "ELBListenerModify"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "irsa_alb_controller" {
  name   = "${local.name_prefix}-irsa-alb-controller-inline"
  role   = aws_iam_role.irsa_alb_controller.id
  policy = data.aws_iam_policy_document.irsa_alb_controller_policy.json
}

# ---------------------------------------------------------------------------
# IRSA -- ExternalDNS
# Scoped to the specific Route53 zone used by this deployment.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_external_dns_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_external_dns" {
  name               = "${local.name_prefix}-irsa-external-dns"
  assume_role_policy = data.aws_iam_policy_document.irsa_external_dns_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "irsa_external_dns_policy" {
  statement {
    sid    = "ExternalDNSChangeRecords"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    # Scoped to the specific zone to prevent ExternalDNS from touching other zones.
    resources = [
      var.route53_zone_id != "" ? "arn:aws:route53:::hostedzone/${var.route53_zone_id}" : "arn:aws:route53:::hostedzone/*"
    ]
  }

  statement {
    sid    = "ExternalDNSListZones"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "irsa_external_dns" {
  name   = "${local.name_prefix}-irsa-external-dns-inline"
  role   = aws_iam_role.irsa_external_dns.id
  policy = data.aws_iam_policy_document.irsa_external_dns_policy.json
}
