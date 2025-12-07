####################################################################################################
###                                                                                              ###
###                                       EKS AUTH CONFIG                                        ###
###                                                                                              ###
####################################################################################################

# Data sources removed - not needed for aws-auth configmap

# Current account (for IAM ARNs)
data "aws_caller_identity" "current" {}

locals {
  oidc_provider_url = replace(aws_eks_cluster.gitops_eks.arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
}

# render Admin & Developer users list with the structure required by EKS module
locals {
  admin_user_map_users = [
    for admin_user in var.admin_users :
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${admin_user}"
      username = admin_user
      groups   = ["system:masters"]
    }
  ]
}

# Update the existing aws-auth ConfigMap
# CRITICAL: This must be created BEFORE nodes try to join
# EKS creates a default aws-auth ConfigMap, we just update it
# Do NOT depend on node group - that creates a circular dependency!
resource "kubernetes_config_map" "aws_auth" {
  count = var.enable_aws_auth_configmap ? 1 : 0

  provider = kubernetes.gitops

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.gitops_eks_nodes.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
    mapUsers = yamlencode(local.admin_user_map_users)
  }

  # CRITICAL: Only depend on cluster, NOT node group
  # Nodes need this ConfigMap to exist BEFORE they can join
  depends_on = [
    aws_eks_cluster.gitops_eks
  ]
}
