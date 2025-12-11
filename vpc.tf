
# Create single VPC.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name   = "vpc-${var.name_region}"
    Budget = var.networking_budget
  }
}

# Default DHCP Options for VPC.
resource "aws_vpc_dhcp_options" "legacy_dhcp_options" {
  domain_name         = var.default_internal_domain
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name   = "legacy-dhcp-opts-${var.name_region}"
    Budget = var.networking_budget
  }
}

# Associate the DHCP Options to the VPC.
resource "aws_vpc_dhcp_options_association" "main_vpc_dhcp_opts" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.legacy_dhcp_options.id
}

# Create private route table for EKS subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name   = "private-route-table-${var.name_region}"
    Budget = var.networking_budget
  }
}

# VPC ACLs, aka firewall rules.
# Note: aws_default_network_acl manages the default ACL for the VPC
resource "aws_default_network_acl" "default_acl" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # Subnets the ACLs will apply to - only EKS subnets for cross-cluster setup
  subnet_ids = concat(
    [for subnet in aws_subnet.private_eks_prod : subnet.id],
    [for subnet in aws_subnet.private_eks_gitops : subnet.id]
  )

  tags = {
    Name   = "vpc-default-acl-${var.name_region}"
    Budget = var.networking_budget
  }

  egress {
    protocol   = -1      # -1 = "All"
    rule_no    = 100     # Lower number is higher priority (matched first)
    action     = "allow" # "allow" or "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0 # 0/0 for all ports
    to_port    = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Brazilian IP that was running a wide-scale, high-ish volume directory scan against most of our
  # infrastructure that was scaring poor DanDomain. Can probably be removed after a while.
  ingress {
    protocol   = -1
    rule_no    = 90
    action     = "deny"
    cidr_block = "201.1.115.69/32"
    from_port  = 0
    to_port    = 0
  }

}
