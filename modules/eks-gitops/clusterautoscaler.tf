####################################################################################################
###                                                                                              ###
###                                   EKS CLUSTER AUTOSCALER                                     ###
###                                                                                              ###
####################################################################################################

locals {
  autoscaler_service_account_namespace = "kube-system"
  autoscaler_service_account_name      = "${aws_eks_cluster.gitops_eks.name}-cluster-autoscaler"
  autoscaler_cluster_name              = aws_eks_cluster.gitops_eks.name
}

# Create OIDC provider for the EKS cluster
# Note: This is created unconditionally as it's needed by EBS CSI, Load Balancer Controller, and Cluster Autoscaler
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.eks_oidc_thumbprint]
  url             = aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer

  tags = {
    Name   = "${local.autoscaler_cluster_name}-oidc"
    Budget = var.proc_budget
  }
}

# IAM role for the cluster autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name = "${local.autoscaler_cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com",
            "${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:${local.autoscaler_service_account_name}"
          }
        }
      }
    ]
  })

  tags = {
    Name   = "${local.autoscaler_cluster_name}-cluster-autoscaler"
    Budget = var.proc_budget
  }
}

# IAM policy for the cluster autoscaler
data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${local.autoscaler_cluster_name}"
      values   = ["owned"]
    }
  }
}

# Create the IAM policy
resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name        = "${local.autoscaler_cluster_name}-cluster-autoscaler"
  description = "Policy for cluster autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler[0].json
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

# Create the service account for cluster autoscaler
resource "kubernetes_service_account" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  provider = kubernetes.gitops

  metadata {
    name      = local.autoscaler_service_account_name
    namespace = local.autoscaler_service_account_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler[0].arn
    }
  }

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth
  ]
}

# Create the cluster autoscaler deployment using Helm
resource "helm_release" "cluster-autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  provider = helm.gitops

  name             = "${local.autoscaler_cluster_name}-cluster-autoscaler"
  namespace        = local.autoscaler_service_account_namespace
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.35.0"
  create_namespace = false

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = local.autoscaler_service_account_name
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = local.autoscaler_cluster_name
  }

  set {
    name  = "autoDiscovery.enabled"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "extraArgs.scale-down-enabled"
    value = "true"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "5m"
  }

  set {
    name  = "extraArgs.leader-elect"
    value = "true"
  }

  set {
    name  = "extraArgs.leader-elect-lease-duration"
    value = "15s"
  }

  set {
    name  = "extraArgs.leader-elect-renew-deadline"
    value = "10s"
  }

  set {
    name  = "extraArgs.leader-elect-retry-period"
    value = "2s"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }

  # Add verbosity level for better debugging
  set {
    name  = "extraArgs.v"
    value = "4"
  }

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth,
    kubernetes_service_account.cluster_autoscaler
  ]
}
