####################################################################################################
###                                                                                              ###
###                                   Terraform  Configuration                                   ###
###                                                                                              ###
####################################################################################################

terraform {
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
  required_version = "~> 1.12.0"
}
