####################################################################################################
###                                                                                              ###
###                                       EKS NETWORK                                            ###
###                                                                                              ###
####################################################################################################

# VPC Endpoint for EKS
# CRITICAL: This must be in the SAME subnets as the nodes or nodes won't be able to reach it
# NOTE: Only ONE EKS endpoint per VPC can have private_dns_enabled=true
# Since GitOps cluster creates it first, we disable private DNS here and use the shared endpoint
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids # Must match node subnets or be in same AZs
  security_group_ids  = [aws_security_group.eks_cluster.id, aws_security_group.eks_nodes.id]
  private_dns_enabled = false # Disabled because GitOps cluster already has one with private DNS

  tags = {
    Name   = "${local.cluster_name}-endpoint"
    Budget = var.proc_budget
  }

  depends_on = [
    aws_eks_cluster.proc_eks,
    aws_security_group.eks_cluster,
    aws_security_group.eks_nodes
  ]
}

# Security group for the EKS control plane
resource "aws_security_group" "eks_cluster" {
  name   = "${local.cluster_name}-sg"
  vpc_id = var.vpc_id

  tags = {
    Name   = "${local.cluster_name}-sg"
    Budget = var.proc_budget
  }
}

# Allow inbound HTTPS traffic from VPC and office
resource "aws_security_group_rule" "cluster_ingress_https" {
  description       = "Allow inbound HTTPS traffic from VPC and office"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_cluster.id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = [var.vpc_cidr]
}

# Allow outbound traffic to VPC and office
resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow outbound traffic to VPC and office"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_cluster.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [var.vpc_cidr]
}

# Security group for EKS worker nodes
resource "aws_security_group" "eks_nodes" {
  name   = "${local.cluster_name}-nodes-sg"
  vpc_id = var.vpc_id

  tags = {
    Name   = "${local.cluster_name}-nodes-sg"
    Budget = var.proc_budget
  }
}

# Allow all outbound traffic from nodes
# CRITICAL: Nodes need this to reach VPC endpoints and bootstrap
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Node all egress - required for VPC endpoints and bootstrap"
}

# Allow inbound traffic from control plane to nodes
resource "aws_security_group_rule" "nodes_ingress_cluster" {
  description              = "Allow cluster API Server to communicate with the nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  to_port                  = 0
  type                     = "ingress"
}

# Allow nodes to communicate with EKS control plane
resource "aws_security_group_rule" "nodes_ingress_eks" {
  description              = "Allow nodes to communicate with EKS control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
  to_port                  = 443
  type                     = "ingress"
}

# Allow EKS control plane to communicate with nodes
resource "aws_security_group_rule" "eks_ingress_nodes" {
  description              = "Allow EKS control plane to communicate with nodes"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 443
  type                     = "ingress"
}
