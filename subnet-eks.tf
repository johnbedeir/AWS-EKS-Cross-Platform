####################################################################################################
###                                                                                              ###
###                            EKS Production Subnet Definitions                                 ###
###                                                                                              ###
####################################################################################################

# Create dedicated EKS production subnets for application deployment
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices (2 AZs for high availability)
  eks_prod_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "aws_subnet" "private_eks_prod" {
  for_each = {
    for idx, cidr in var.private_eks_prod_subnets : idx => {
      cidr = cidr
      az   = local.eks_prod_azs[idx]
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name   = "private-eks-prod-subnet-${var.name_region}-${format("%02d", each.key)}"
    Budget = var.proc_budget # EKS production budget
    # EKS-specific tags for cluster discovery
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

####################################################################################################
###                                                                                              ###
###                                  Route Table Associations                                    ###
###                                                                                              ###
####################################################################################################

# Associate the EKS production subnets with the private route table
# CRITICAL: These associations MUST exist before node groups are created
# Without route tables, nodes cannot route traffic to VPC endpoints or EKS API
resource "aws_route_table_association" "private_eks_prod" {
  for_each = aws_subnet.private_eks_prod

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id

  # Ensure route table and subnet exist before creating association
  depends_on = [
    aws_route_table.private,
    aws_subnet.private_eks_prod
  ]
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output subnet IDs for use in EKS configuration
output "eks_prod_subnet_ids" {
  description = "List of EKS production subnet IDs"
  value       = [for subnet in aws_subnet.private_eks_prod : subnet.id]
}

output "eks_prod_subnet_cidrs" {
  description = "List of EKS production subnet CIDRs"
  value       = [for subnet in aws_subnet.private_eks_prod : subnet.cidr_block]
}
