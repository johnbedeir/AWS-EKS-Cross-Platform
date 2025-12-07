####################################################################################################
###                                                                                              ###
###                                       EKS NODE GROUP                                         ###
###                                                                                              ###
####################################################################################################

resource "aws_eks_node_group" "gitops_prod" {
  cluster_name    = aws_eks_cluster.gitops_eks.name
  node_group_name = "gitops-prod"
  node_role_arn   = aws_iam_role.gitops_eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  instance_types = var.node_group_instance_types

  tags = {
    "k8s.io/cluster-autoscaler/enabled"                            = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.gitops_eks.name}" = "owned"
    Budget                                                         = var.proc_budget
  }

  # CRITICAL: Node group must wait for:
  # 1. Cluster to be ready
  # 2. Security groups to exist
  # 3. VPC endpoints to be available (nodes need these to bootstrap)
  # 4. aws-auth ConfigMap to exist (nodes need this to authenticate)
  # NOTE: Route table associations are handled at the root module level
  # They must exist before nodes are created (enforced via null_resource dependencies)
  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_security_group.eks_nodes,
    aws_vpc_endpoint.eks,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    kubernetes_config_map.aws_auth
  ]

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }
}
