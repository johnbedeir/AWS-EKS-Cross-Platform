###
# Declare all variables, without values, enviroment specific values are loaded later.
###

###
# Region related settings.

variable "aws_account_id" {
  description = "The AWS account ID."
  type        = string
}

variable "region" {
  description = "The AWS region to work in."
  type        = string
}


variable "az_primary" {
  description = "The primary availability zone to use."
  type        = string
}

variable "az_secondary" {
  description = "The secondary availability zone to use."
  type        = string
}

variable "default_internal_domain" {
  description = "The default AWS internal domain."
  type        = string
}

###
# IP settings. (ranges)

variable "vpc_cidr" {
  description = "VPC IP Range in CIDR notation."
  type        = string
}

###
# Budget tag values.

variable "networking_budget" {
  description = "Value for the Budget tag for networking resources."
  type        = string
}

variable "proc_budget" {
  description = "Value for the Budget tag for processing resources."
  type        = string
}


###
# Other tag values

variable "env_tag" {
  description = "Value of the env tag, probably 'prod' or 'dev'."
  type        = string
}

variable "replicated_region" {
  description = "The AWS region used for bucket and secret replication."
  type        = string
}







###
# Things that make other things pretty.


variable "name_region" {
  description = "The name of the region. Used to name things. eg: cache-eu-00"
  type        = string
}



####################################################################################################
###                                                                                              ###
###                                       EKS VARIABLES                                          ###
###                                                                                              ###
####################################################################################################

variable "name_prefix" {
  description = "The prefix for the name of the EKS cluster."
  type        = string
}

variable "environment" {
  description = "The environment for the EKS cluster."
  type        = string
}

variable "admin_users" {
  type        = list(string)
  description = "List of Kubernetes admins."
}

variable "eks_oidc_id" {
  description = "OIDC root CA thumbprint for the EKS cluster"
  type        = string
}

variable "eks_oidc_thumbprint" {
  description = "OIDC provider root CA thumbprint for the EKS cluster"
  type        = string
}

variable "eks_version" {
  description = "The version of the EKS cluster."
  type        = string
}

# Blue-Green Node Group Variables
variable "node_group_new_instance_types" {
  description = "Instance types for the new managed node group (blue-green migration)"
  type        = list(string)
}

variable "node_group_new_desired_size" {
  description = "Desired number of nodes in the new node group"
  type        = number
}

variable "node_group_new_min_size" {
  description = "Minimum number of nodes in the new node group"
  type        = number
}

variable "node_group_new_max_size" {
  description = "Maximum number of nodes in the new node group"
  type        = number
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}


variable "datadog_api_name" {
  description = "The name of the Datadog API key secret in AWS Secrets Manager."
  type        = string
}

variable "datadog_api_key_value" {
  description = "The Datadog API key value (will be stored in AWS Secrets Manager)."
  type        = string
  sensitive   = true
}

# GitOps EKS Cluster Variables
variable "gitops_name_prefix" {
  description = "Name prefix for the GitOps EKS cluster"
  type        = string
}

variable "gitops_environment" {
  description = "Environment name for the GitOps EKS cluster"
  type        = string
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps EKS cluster"
  type        = string
}

variable "gitops_eks_version" {
  description = "Kubernetes version for the GitOps EKS cluster"
  type        = string
}

variable "gitops_admin_users" {
  description = "List of admin users for the GitOps EKS cluster"
  type        = list(string)
}

variable "gitops_node_group_instance_types" {
  description = "Instance types for the GitOps EKS node group"
  type        = list(string)
}

variable "gitops_node_group_desired_size" {
  description = "Desired size of the GitOps EKS node group"
  type        = number
}

variable "gitops_node_group_min_size" {
  description = "Minimum size of the GitOps EKS node group"
  type        = number
}

variable "gitops_node_group_max_size" {
  description = "Maximum size of the GitOps EKS node group"
  type        = number
}

variable "gitops_datadog_api_name" {
  description = "The name of the Datadog API key secret for GitOps cluster in AWS Secrets Manager."
  type        = string
}

variable "gitops_datadog_api_key_value" {
  description = "The Datadog API key value for GitOps cluster (will be stored in AWS Secrets Manager)."
  type        = string
  sensitive   = true
}

# EKS Production Subnet Variables
variable "private_eks_prod_subnets" {
  description = "List of IP ranges for EKS production subnets in CIDR notation."
  type        = list(string)
}

# EKS GitOps Management Subnet Variables
variable "private_eks_gitops_subnets" {
  description = "List of IP ranges for EKS GitOps management subnets in CIDR notation."
  type        = list(string)
}

# Public Subnet Variables
variable "public_subnets" {
  description = "List of IP ranges for public subnets in CIDR notation."
  type        = list(string)
}
