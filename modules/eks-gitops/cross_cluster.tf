####################################################################################################
###                                                                                              ###
###                                  CROSS-CLUSTER COMMUNICATION                                  ###
###                                                                                              ###
####################################################################################################

# IAM Role for ArgoCD to manage external clusters
resource "aws_iam_role" "argocd_cross_cluster_access" {
  count = var.enable_argocd && var.target_cluster_name != "" ? 1 : 0

  name = "${var.cluster_name}-argocd-cross-cluster-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-application-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-argocd-cross-cluster-access"
    Environment = var.environment
    Budget      = var.proc_budget
  }
}

# IAM Policy for ArgoCD cross-cluster access
resource "aws_iam_role_policy" "argocd_cross_cluster_access" {
  count = var.enable_argocd && var.target_cluster_name != "" ? 1 : 0

  name = "${var.cluster_name}-argocd-cross-cluster-access"
  role = aws_iam_role.argocd_cross_cluster_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "sts:AssumeRole",
          "sts:AssumeRoleWithWebIdentity",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.target_cluster_name}-argocd-gitops-access"
        ]
      }
    ]
  })
}

# NOTE: Cluster secrets for cross-cluster connectivity are now managed manually 
# using bearer token authentication to avoid AWS IAM role timeout issues.
# See README.md for the complete bearer token authentication setup guide.

# Security group rule to allow ArgoCD to communicate with target cluster
resource "aws_security_group_rule" "argocd_to_target_cluster" {
  count = var.enable_argocd && var.target_cluster_name != "" ? 1 : 0

  description              = "Allow ArgoCD GitOps to communicate with target cluster"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  to_port                  = 443
  type                     = "egress"
  source_security_group_id = aws_security_group.eks_cluster.id
}

# Note: ArgoCD service account annotation is handled in argocd.tf
# to avoid conflicts with Helm-managed resources
