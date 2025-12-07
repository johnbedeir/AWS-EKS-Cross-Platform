####################################################################################################
###                                                                                              ###
###                                      EKS MODULE OUTPUTS                                      ###
###                                                                                              ###
####################################################################################################


output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.gitops_eks.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.gitops_eks.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.gitops_eks.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer
}

output "chartmuseum_loadbalancer_url" {
  description = "LoadBalancer URL for ChartMuseum"
  value       = var.enable_chartmuseum && length(data.kubernetes_service.chartmuseum) > 0 && data.kubernetes_service.chartmuseum[0].status != null && length(data.kubernetes_service.chartmuseum[0].status) > 0 && data.kubernetes_service.chartmuseum[0].status[0].load_balancer != null && length(data.kubernetes_service.chartmuseum[0].status[0].load_balancer) > 0 && data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress != null && length(data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress) > 0 ? "http://${data.kubernetes_service.chartmuseum[0].status[0].load_balancer[0].ingress[0].hostname}:8080" : null
}
