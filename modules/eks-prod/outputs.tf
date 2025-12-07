####################################################################################################
###                                                                                              ###
###                                      EKS MODULE OUTPUTS                                      ###
###                                                                                              ###
####################################################################################################


output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.proc_eks.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.proc_eks.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.proc_eks.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.proc_eks.identity[0].oidc[0].issuer
}
