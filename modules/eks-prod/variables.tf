####################################################################################################
###                                                                                              ###
###                                     EKS MODULE VARIABLES                                     ###
###                                                                                              ###
####################################################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}


variable "region" {
  description = "AWS region (used by autoscaler and other components)"
  type        = string
}

variable "aws_region" {
  description = "AWS region used in IAM policy ARNs where required"
  type        = string
}

# EKS OIDC
variable "eks_oidc_thumbprint" {
  description = "OIDC provider root CA thumbprint for the EKS cluster"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID used for IAM trust policies and ARNs"
  type        = string
}


variable "vpc_cidr" {
  description = "CIDR block of the VPC (used for security group rules)"
  type        = string
}


# Blue-Green Node Group Variables
variable "node_group_new_instance_types" {
  description = "Instance types for the new managed node group (blue-green migration)"
  type        = list(string)
  default     = []
}

variable "node_group_new_desired_size" {
  description = "Desired number of nodes in the new node group"
  type        = number
  default     = 0
}

variable "node_group_new_min_size" {
  description = "Minimum number of nodes in the new node group"
  type        = number
  default     = 0
}

variable "node_group_new_max_size" {
  description = "Maximum number of nodes in the new node group"
  type        = number
  default     = 25
}


variable "admin_users" {
  description = "IAM user names to grant cluster-admin access (system:masters)"
  type        = list(string)
  default     = []
}

variable "proc_budget" {
  description = "Budget tag value to apply across EKS resources"
  type        = string
}

variable "datadog_api_name" {
  description = "Name of the Secret in AWS Secrets Manager for the Datadog API key"
  type        = string
}

variable "enable_argocd_access" {
  description = "Enable ArgoCD access from GitOps cluster"
  type        = bool
  default     = false
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps cluster for ArgoCD access"
  type        = string
  default     = ""
}

variable "enable_aws_auth_configmap" {
  description = "Whether to manage the aws-auth ConfigMap via Terraform"
  type        = bool
  default     = false
}

variable "enable_metrics_server" {
  description = "Whether to install Metrics Server via Helm"
  type        = bool
  default     = false
}

variable "enable_datadog" {
  description = "Whether to install Datadog agent via Helm"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Whether to install Cluster Autoscaler via Helm"
  type        = bool
  default     = false
}



variable "vpc_id" {
  description = "VPC ID where EKS resources are created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS control plane and node groups"
  type        = list(string)
}

variable "endpoint_subnet_ids" {
  description = "Subnet IDs to place the EKS VPC interface endpoint in"
  type        = list(string)
}
