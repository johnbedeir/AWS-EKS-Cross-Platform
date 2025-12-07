locals {
  chartmuseum_values = <<EOF
    env:
      open:
        DISABLE_API: false
        STORAGE: local
    service:
      type: LoadBalancer
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: alb
        service.beta.kubernetes.io/aws-load-balancer-scheme: internal
    persistence:
      enabled: true
      accessMode: ReadWriteOnce
      size: ${var.chartmuseum_storage_size}
      storageClass: ${var.chartmuseum_storage_class}
    EOF
}

resource "helm_release" "chartmuseum" {
  provider         = helm.gitops
  count            = var.enable_chartmuseum ? 1 : 0
  name             = "${local.cluster_name}-chartmuseum"
  repository       = "https://chartmuseum.github.io/charts"
  chart            = "chartmuseum"
  version          = "3.10.4"
  cleanup_on_fail  = true
  namespace        = "chartmuseum"
  create_namespace = true
  wait             = false # Don't wait for LoadBalancer to be ready (it will be created asynchronously)

  values = [local.chartmuseum_values]

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth,
    helm_release.aws_load_balancer_controller # CRITICAL: AWS Load Balancer Controller must be ready
  ]
}

# Data source to get ChartMuseum service information for LoadBalancer URL
data "kubernetes_service" "chartmuseum" {
  count = var.enable_chartmuseum ? 1 : 0

  provider = kubernetes.gitops

  metadata {
    name      = "chartmuseum"
    namespace = "chartmuseum"
  }

  depends_on = [helm_release.chartmuseum]
}
