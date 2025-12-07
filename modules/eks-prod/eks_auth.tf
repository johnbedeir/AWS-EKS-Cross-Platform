####################################################################################################
###                                                                                              ###
###                                       EKS AUTH CONFIG                                        ###
###                                                                                              ###
####################################################################################################

# Data source to get information about the EKS cluster
# Note: This data source is used by the provider configuration in eks.tf
# Using the cluster resource name directly creates an implicit dependency
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.proc_eks.name
}

# Data source to get authentication info for the EKS cluster
# Note: This data source is used by the provider configuration in eks.tf
# Using the cluster resource name directly creates an implicit dependency
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.proc_eks.name
}

# Current account (for IAM ARNs)
data "aws_caller_identity" "current" {}

locals {
  oidc_provider_url = replace(aws_eks_cluster.proc_eks.arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
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
resource "kubernetes_config_map" "aws_auth" {
  count = var.enable_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [
        {
          rolearn  = aws_iam_role.eks_nodes.arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups = [
            "system:bootstrappers",
            "system:nodes"
          ]
        }
      ],
      var.enable_argocd_access ? [
        {
          rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.gitops_cluster_name}-argocd-cross-cluster-access"
          username = "argocd-gitops"
          groups = [
            "system:masters"
          ]
        }
      ] : []
    ))
    mapUsers = yamlencode(local.admin_user_map_users)
  }
}
