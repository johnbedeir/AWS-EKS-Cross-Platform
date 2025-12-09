####################################################################################################
###                                                                                              ###
###                                       EKS MODULE                                             ###
###                                                                                              ###
####################################################################################################

# Call the EKS module using the existing subnets from subnet-eks.tf
module "eks" {
  source = "./modules/eks-prod"

  # General
  name_prefix  = var.name_prefix
  environment  = var.environment
  cluster_name = var.cluster_name
  eks_version  = var.eks_version

  # AWS account
  region         = var.region
  aws_region     = var.region
  aws_account_id = var.aws_account_id

  # Networking
  vpc_cidr = var.vpc_cidr
  vpc_id   = aws_vpc.main.id
  # CRITICAL: Node subnets MUST match endpoint subnets
  # VPC endpoints can only be in 2 subnets (one per AZ)
  # So nodes must also only use these 2 subnets
  private_subnet_ids = [
    aws_subnet.private_eks_prod[0].id,
    aws_subnet.private_eks_prod[1].id
  ]
  # Use EKS production subnets for VPC endpoints
  endpoint_subnet_ids = [
    aws_subnet.private_eks_prod[0].id,
    aws_subnet.private_eks_prod[1].id
  ]

  # CRITICAL: Route table associations must exist before node groups are created
  # Since modules with local providers can't use depends_on, we reference the null_resource
  # which ensures associations are created first. The module will implicitly wait for it.
  # This is handled via the subnet references - Terraform will create associations
  # before the subnets are used by the module.

  # Node group (migrated to c6i.2xlarge)
  node_group_new_instance_types = var.node_group_new_instance_types
  node_group_new_desired_size   = var.node_group_new_desired_size
  node_group_new_min_size       = var.node_group_new_min_size
  node_group_new_max_size       = var.node_group_new_max_size

  # Auth
  admin_users = var.admin_users


  # OIDC
  eks_oidc_thumbprint = var.eks_oidc_thumbprint

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_name = var.datadog_api_name

  # ArgoCD GitOps access
  # Pass the actual cluster name that matches the GitOps module's var.cluster_name
  # The GitOps module constructs cluster name as: ${name_prefix}-${environment}
  # This is used to construct the IAM role name: ${cluster_name}-argocd-cross-cluster-access
  enable_argocd_access = true
  gitops_cluster_name  = "${var.gitops_name_prefix}-${var.gitops_environment}"

  # Enable optional components to match existing infrastructure
  enable_aws_auth_configmap = true
  enable_metrics_server     = true
  enable_datadog            = true
  enable_cluster_autoscaler = true
}








