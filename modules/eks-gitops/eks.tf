####################################################################################################
###                                                                                              ###
###                                       EKS CLUSTER                                            ###
###                                                                                              ###
####################################################################################################

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"
}

# Data source for GitOps cluster auth
# This must be created after the cluster exists
data "aws_eks_cluster_auth" "gitops_cluster" {
  name = aws_eks_cluster.gitops_eks.name
}

# Provider configuration for this specific cluster
# Using exec authentication to ensure proper token refresh
provider "kubernetes" {
  alias = "gitops"

  host                   = aws_eks_cluster.gitops_eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.gitops_eks.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.gitops_eks.name
    ]
  }
}

provider "helm" {
  alias = "gitops"
  kubernetes {
    host                   = aws_eks_cluster.gitops_eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.gitops_eks.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.gitops_eks.name
      ]
    }
  }
}

resource "aws_eks_cluster" "gitops_eks" {
  name     = local.cluster_name
  role_arn = aws_iam_role.gitops_eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = []

  tags = {
    Budget = var.proc_budget
  }
}








