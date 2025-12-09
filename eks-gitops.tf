####################################################################################################
###                                                                                              ###
###                                    EKS GitOps Module                                          ###
###                                                                                              ###
####################################################################################################

# Call the EKS GitOps module using the new subnets from subnet_eks_gitops.tf
module "eks_gitops" {
  source = "./modules/eks-gitops"

  # General
  name_prefix  = var.gitops_name_prefix
  environment  = var.gitops_environment
  cluster_name = var.gitops_cluster_name
  eks_version  = var.gitops_eks_version

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
    aws_subnet.private_eks_gitops[0].id,
    aws_subnet.private_eks_gitops[1].id
  ]
  # Use EKS GitOps subnets for VPC endpoints
  # CRITICAL: Must match node subnets exactly so ALL nodes can reach endpoints
  # VPC endpoints can only have ONE subnet per AZ, so we use 2 subnets in different AZs
  endpoint_subnet_ids = [
    aws_subnet.private_eks_gitops[0].id,
    aws_subnet.private_eks_gitops[1].id
  ]

  # Public subnets for internet-facing LoadBalancers (ArgoCD, Chartmuseum)
  public_subnet_ids = [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id
  ]

  # CRITICAL: Route table associations must exist before node groups are created
  # Since modules with local providers can't use depends_on, we reference the null_resource
  # which ensures associations are created first. The module will implicitly wait for it.
  # This is handled via the subnet references - Terraform will create associations
  # before the subnets are used by the module.

  # Node group - smaller instances for GitOps management
  node_group_instance_types = var.gitops_node_group_instance_types
  node_group_desired_size   = var.gitops_node_group_desired_size
  node_group_min_size       = var.gitops_node_group_min_size
  node_group_max_size       = var.gitops_node_group_max_size

  # Auth - same admin users as production
  admin_users = var.gitops_admin_users


  # OIDC
  eks_oidc_thumbprint = var.eks_oidc_thumbprint
  eks_oidc_id         = var.eks_oidc_id

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_name = var.gitops_datadog_api_name

  # Cross-cluster communication
  target_cluster_name     = module.eks.cluster_name
  target_cluster_endpoint = module.eks.cluster_endpoint
  target_cluster_ca_data  = module.eks.cluster_certificate_authority_data

  # Enable GitOps-specific components
  enable_aws_auth_configmap = true
  enable_metrics_server     = true
  enable_datadog            = true
  enable_cluster_autoscaler = true
  enable_chartmuseum        = true
  enable_argocd             = true
}
