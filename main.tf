####################################################################################################
###                                                                                              ###
###                                   Terraform  Configuration                                   ###
###                                                                                              ###
####################################################################################################

terraform {

  # Latest version on the registry when I refreshed this.
  # Remember to keep modules up to date with this.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.67.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
  }
  # Terraform version requirement - supports 1.5.7 and above
  required_version = ">= 1.5.7"

  # Backend configuration removed for new project
  # To use S3 backend, uncomment and configure:
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "terraform.tfstate"
  #   region = "your-region"
  # }
}

####################################################################################################
###                                                                                              ###
###                                    Provider Configuration                                    ###
###                                                                                              ###
####################################################################################################

# Configure AWS provider.
provider "aws" {
  profile = "default"
  region  = var.region

  # Set a default tag to indicate this resource is managed via Terraform and not in AWS.
  default_tags {
    tags = {
      Terraform     = "True"
      Budget_region = var.name_region
      env           = var.env_tag
    }
  }
}

# Configure an AWS provider for the recpliation region.
provider "aws" {
  alias   = "replication_target"
  profile = "default"
  region  = var.replicated_region

  # Set a default tag to indicate this resource is managed via Terraform and not in AWS.
  default_tags {
    tags = {
      Terraform     = "True"
      Budget_region = var.name_region
      env           = var.env_tag
    }
  }
}

# Kubernetes and Helm providers are configured inside the EKS modules
# This avoids circular dependencies where providers would need data sources
# that depend on modules that need providers

####################################################################################################
###                                                                                              ###
###                                     Misc & Data sources                                      ###
###                                                                                              ###
####################################################################################################

# Get the current AWS caller identity, needed to get the account number.
data "aws_caller_identity" "current" {}

# EKS cluster data sources for external access (if needed)
# Note: These are optional and only needed if you want to access clusters from outside the modules
# The modules configure their own providers internally
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

data "aws_eks_cluster" "gitops_cluster" {
  name = module.eks_gitops.cluster_name

  depends_on = [
    module.eks_gitops
  ]
}

data "aws_eks_cluster_auth" "gitops_cluster" {
  name = module.eks_gitops.cluster_name

  depends_on = [
    module.eks_gitops
  ]
}


####################################################################################################
###                                                                                              ###
###                                    EKS-Only Configuration                                    ###
###                                                                                              ###
###  This project is configured for EKS-only deployment. All legacy modules (IAM, CICD,        ###
###  databases, CDN, API clusters, etc.) have been removed. Only EKS production and GitOps     ###
###  clusters are managed by this Terraform configuration.                                      ###
###                                                                                              ###
####################################################################################################


