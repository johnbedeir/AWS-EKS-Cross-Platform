####################################################################################################
###                                                                                              ###
###                            EKS GitOps Management Subnet Definitions                          ###
###                                                                                              ###
####################################################################################################

# Create dedicated EKS GitOps subnets for ArgoCD and ChartMuseum management
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices (2 AZs for high availability)
  eks_gitops_azs = [
    var.az_primary,
    var.az_secondary
  ]

  # Get the actual GitOps cluster name from variables
  # This is used in subnet tags for AWS Load Balancer Controller
  gitops_cluster_name = var.gitops_cluster_name
}

resource "aws_subnet" "private_eks_gitops" {
  for_each = {
    for idx, cidr in var.private_eks_gitops_subnets : idx => {
      cidr = cidr
      az   = local.eks_gitops_azs[idx]
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name   = "private-eks-gitops-subnet-${var.name_region}-${format("%02d", each.key)}"
    Budget = var.proc_budget # GitOps management budget
    # EKS-specific tags for cluster discovery
    # CRITICAL: Cluster name must match actual cluster name for AWS Load Balancer Controller
    "kubernetes.io/role/internal-elb"                    = "1"
    "kubernetes.io/cluster/${local.gitops_cluster_name}" = "shared"
  }
}

####################################################################################################
###                                                                                              ###
###                                  Route Table Associations                                    ###
###                                                                                              ###
####################################################################################################

# Associate the EKS GitOps subnets with the private route table
# CRITICAL: These associations MUST exist before node groups are created
# Without route tables, nodes cannot route traffic to VPC endpoints or EKS API
resource "aws_route_table_association" "private_eks_gitops" {
  for_each = aws_subnet.private_eks_gitops

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id

  # Ensure route table and subnet exist before creating association
  depends_on = [
    aws_route_table.private,
    aws_subnet.private_eks_gitops
  ]
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output subnet IDs for use in EKS GitOps configuration
output "eks_gitops_subnet_ids" {
  description = "List of EKS GitOps subnet IDs"
  value       = [for subnet in aws_subnet.private_eks_gitops : subnet.id]
}

output "eks_gitops_subnet_cidrs" {
  description = "List of EKS GitOps subnet CIDRs"
  value       = [for subnet in aws_subnet.private_eks_gitops : subnet.cidr_block]
}
