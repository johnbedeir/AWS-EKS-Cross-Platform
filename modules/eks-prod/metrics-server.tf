# Metrics Server deployment using Helm
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name             = "${local.cluster_name}-metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  timeout          = 600 # 10 minutes timeout
  wait             = true


  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  depends_on = [
    aws_eks_cluster.proc_eks,
    aws_eks_node_group.prod,
    kubernetes_config_map.aws_auth
  ]

  # Note: Metrics Server doesn't need IAM role annotation - it runs with node IAM role
}
