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
# EKS providers — only active when deployment_type = "eks".
# When deployment_type = "ec2", the data sources have count = 0 and
# try() returns "" so the providers initialize harmlessly with no resources.
#
# NOTE: EKS deployments require two terraform apply passes:
#   1. terraform apply  — creates the EKS cluster (AWS resources)
#   2. terraform apply  — creates Helm releases and Kubernetes resources
# This is a known Terraform limitation when providers depend on resource outputs.
# ---------------------------------------------------------------------------

data "aws_eks_cluster" "this" {
  count = var.deployment_type == "eks" ? 1 : 0
  name  = module.airbyte_eks[0].cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.deployment_type == "eks" ? 1 : 0
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
