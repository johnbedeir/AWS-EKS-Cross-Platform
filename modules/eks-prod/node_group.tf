####################################################################################################
###                                                                                              ###
###                                       EKS NODE GROUP                                         ###
###                                                                                              ###
####################################################################################################

# Production Node Group
resource "aws_eks_node_group" "prod" {
  cluster_name    = aws_eks_cluster.proc_eks.name
  node_group_name = "prod"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = var.node_group_new_desired_size
    max_size     = var.node_group_new_max_size
    min_size     = var.node_group_new_min_size
  }

  instance_types = var.node_group_new_instance_types

  tags = {
    "k8s.io/cluster-autoscaler/enabled"                          = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.proc_eks.name}" = "owned"
    Budget                                                       = var.proc_budget
    Purpose                                                      = "blue-green-migration"
  }

  # CRITICAL: Node group must wait for:
  # 1. Cluster to be ready
  # 2. Security groups to exist
  # NOTE: Route table associations are handled at the root module level
  # They must exist before nodes are created (enforced via null_resource dependencies)
  depends_on = [
    aws_eks_cluster.proc_eks,
    aws_security_group.eks_nodes
  ]

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }
}
