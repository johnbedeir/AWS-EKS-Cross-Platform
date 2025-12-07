####################################################################################################
###                                                                                              ###
###                            Public Subnet Definitions                                          ###
###                                                                                              ###
####################################################################################################

# Create public subnets for NAT Gateway and Internet Gateway
# These are needed for outbound internet access from private subnets
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices
  public_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "aws_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnets : idx => {
      cidr = cidr
      az   = local.public_azs[idx]
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name   = "public-subnet-${var.name_region}-${format("%02d", each.key)}"
    Budget = var.networking_budget
    # EKS-specific tags for cluster discovery
    "kubernetes.io/cluster/eks-prod-production"   = "shared"
    "kubernetes.io/cluster/eks-gitops-production" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

####################################################################################################
###                                                                                              ###
###                            Internet Gateway                                                   ###
###                                                                                              ###
####################################################################################################

# Internet Gateway for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name   = "igw-${var.name_region}"
    Budget = var.networking_budget
  }
}

####################################################################################################
###                                                                                              ###
###                            NAT Gateway                                                        ###
###                                                                                              ###
####################################################################################################

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_gateway" {
  domain = "vpc"

  tags = {
    Name   = "nat-gateway-eip-${var.name_region}"
    Budget = var.networking_budget
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway in primary AZ (single NAT Gateway for cost efficiency)
# Private subnets route through this for internet access
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id # Use first public subnet

  tags = {
    Name   = "nat-gateway-${var.name_region}"
    Budget = var.networking_budget
  }

  depends_on = [aws_internet_gateway.main]
}

####################################################################################################
###                                                                                              ###
###                            Public Route Table                                                 ###
###                                                                                              ###
####################################################################################################

# Public route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name   = "public-route-table-${var.name_region}"
    Budget = var.networking_budget
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

####################################################################################################
###                                                                                              ###
###                            Update Private Route Table                                          ###
###                                                                                              ###
####################################################################################################

# Update private route table to route internet traffic through NAT Gateway
# This allows nodes in private subnets to access the internet
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id

  depends_on = [
    aws_route_table.private,
    aws_nat_gateway.main
  ]
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output public subnet IDs
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

# Output public subnet CIDRs
output "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  value       = [for subnet in aws_subnet.public : subnet.cidr_block]
}
