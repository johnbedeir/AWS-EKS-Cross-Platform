####################################################################################################
###                                                                                              ###
###                                       EKS ADDONS                                             ###
###                                                                                              ###
####################################################################################################

# EKS addon for CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.gitops_eks.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_vpc_endpoint.eks
  ]
}

# EKS addon for VPC CNI networking
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.gitops_eks.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_vpc_endpoint.eks
  ]
}

# EKS addon for kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.gitops_eks.name
  addon_name   = "kube-proxy"

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_vpc_endpoint.eks
  ]
}

# EKS addon for AWS EBS CSI driver
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.gitops_eks.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_vpc_endpoint.eks
  ]
}
