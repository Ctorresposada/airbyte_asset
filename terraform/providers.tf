provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Asset       = "airbyte"
    }
  }
}

# ---------------------------------------------------------------------------
# EKS providers — only active when deployment_type = "eks" AND the cluster
# already exists (eks_cluster_ready = true).
#
# NOTE: EKS deployments require two terraform apply passes:
#   Pass 1 (eks_cluster_ready = false, the default):
#     terraform apply -var-file=variables/eks-dev.tfvars
#     Creates all AWS resources (EKS cluster, RDS, S3, IAM, etc.)
#     The data sources have count = 0 so the Helm/kubernetes providers
#     initialize harmlessly with empty strings and no Helm releases are created.
#
#   Pass 2 (eks_cluster_ready = true):
#     terraform apply -var-file=variables/eks-dev.tfvars -var eks_cluster_ready=true
#     The data sources read the now-existing cluster endpoint and the
#     Helm provider installs Airbyte, ALB controller, and ExternalDNS.
# ---------------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  count = var.deployment_type == "eks" && var.eks_cluster_ready ? 1 : 0
  name  = module.airbyte_eks[0].cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.deployment_type == "eks" && var.eks_cluster_ready ? 1 : 0
  name  = module.airbyte_eks[0].cluster_name
}

provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.this[0].endpoint, "")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data), "")
  token                  = try(data.aws_eks_cluster_auth.this[0].token, "")
}

provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.this[0].endpoint, "")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data), "")
    token                  = try(data.aws_eks_cluster_auth.this[0].token, "")
  }
}
