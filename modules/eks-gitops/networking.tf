####################################################################################################
###                                                                                              ###
###                                       EKS NETWORK                                            ###
###                                                                                              ###
####################################################################################################

# VPC Endpoint for EKS API (nodes need this to register with cluster)
# CRITICAL: This must be in the SAME subnets as the nodes or nodes won't be able to reach it
# NOTE: Only ONE EKS endpoint per VPC can have private_dns_enabled=true
# If there's already an endpoint with private DNS, disable it here
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids # Must match node subnets or be in same AZs
  security_group_ids  = [aws_security_group.eks_cluster.id, aws_security_group.eks_nodes.id]
  private_dns_enabled = false # Disabled to avoid conflict - only one endpoint per VPC can have private DNS

  tags = {
    Name   = "${local.cluster_name}-endpoint"
    Budget = var.proc_budget
  }

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_security_group.eks_cluster,
    aws_security_group.eks_nodes
  ]
}

# VPC Endpoint for ECR API (nodes need this to pull container images)
# CRITICAL: Must be in same subnets as nodes
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids # Must match node subnets
  security_group_ids  = [aws_security_group.eks_cluster.id, aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = {
    Name   = "${local.cluster_name}-ecr-api-endpoint"
    Budget = var.proc_budget
  }

  depends_on = [
    aws_security_group.eks_cluster,
    aws_security_group.eks_nodes
  ]
}

# VPC Endpoint for ECR DKR (Docker Registry API - nodes need this to pull images)
# CRITICAL: Must be in same subnets as nodes
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.endpoint_subnet_ids # Must match node subnets
  security_group_ids  = [aws_security_group.eks_cluster.id, aws_security_group.eks_nodes.id]
  private_dns_enabled = true

  tags = {
    Name   = "${local.cluster_name}-ecr-dkr-endpoint"
    Budget = var.proc_budget
  }

  depends_on = [
    aws_security_group.eks_cluster,
    aws_security_group.eks_nodes
  ]
}

# VPC Endpoint for S3 (nodes need this for bootstrap scripts and logs)
# Gateway endpoints automatically add routes to all route tables in the VPC
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Name   = "${local.cluster_name}-s3-endpoint"
    Budget = var.proc_budget
  }
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

# Allow outbound traffic from cluster to VPC
# This allows cluster to communicate with VPC endpoints
resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow outbound traffic from cluster to VPC"
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

# CRITICAL: Allow VPC endpoints to accept traffic from nodes
# The endpoint uses both cluster and node security groups
# Even though endpoint uses node SG, we need explicit ingress rule allowing nodes to reach it
resource "aws_security_group_rule" "endpoint_ingress_from_nodes" {
  description              = "Allow EKS nodes to reach VPC endpoint (endpoint uses node SG)"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id # Endpoint uses node SG
  source_security_group_id = aws_security_group.eks_nodes.id # Nodes use node SG
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
