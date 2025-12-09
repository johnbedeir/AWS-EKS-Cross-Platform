# Fetch existing Datadog API key from AWS Secrets Manager
data "aws_secretsmanager_secret" "datadog_api_key" {
  name = var.datadog_api_name
}

data "aws_secretsmanager_secret_version" "datadog_api_key_value" {
  secret_id = data.aws_secretsmanager_secret.datadog_api_key.id
}

resource "kubernetes_secret" "datadog_api_key" {
  count = var.enable_datadog ? 1 : 0

  metadata {
    name      = "datadog-secret"
    namespace = "kube-system"
  }

  data = {
    "api-key" = data.aws_secretsmanager_secret_version.datadog_api_key_value.secret_string
  }

  type = "Opaque"

  depends_on = [
    aws_eks_cluster.proc_eks,
    aws_eks_node_group.prod,
    kubernetes_config_map.aws_auth
  ]
}

resource "helm_release" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0

  name             = "${local.cluster_name}-datadog"
  namespace        = "kube-system"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = "3.116.3"
  create_namespace = false

  # Use Kubernetes secret for API key (don't set apiKey directly when using ExistingSecret)
  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_api_key[0].metadata[0].name
  }

  set {
    name  = "datadog.apiKeySecretKey"
    value = "api-key"
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.eu"
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.proc_eks.name
  }

  set {
    name  = "datadog.clusterName"
    value = aws_eks_cluster.proc_eks.name
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  # Kubernetes Jobs monitoring
  set {
    name  = "datadog.collectKubernetesEvents"
    value = "true"
  }

  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  # Enable kube-state-metrics for job metrics
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  set {
    name  = "kubeStateMetrics.rbac.create"
    value = "true"
  }

  # Job-specific metrics collection
  set {
    name  = "datadog.kubernetesStateCoreConfigMap"
    value = "kube-state-metrics"
  }

  # Helm release monitoring
  set {
    name  = "datadog.kubernetesStateCoreConfigMap"
    value = "kube-state-metrics"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerInclude"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectUsingFiles"
    value = "true"
  }

  set {
    name  = "datadog.kubeStateMetrics.core.enabled"
    value = "true"
  }

  set {
    name  = "datadog.kubeStateMetrics.labelJoins"
    value = "kube_job_labels"
  }

  set {
    name  = "datadog.logs.openFilesLimit"
    value = "100"
  }

  depends_on = [
    aws_eks_cluster.proc_eks,
    aws_eks_node_group.prod,
    kubernetes_config_map.aws_auth,
    kubernetes_secret.datadog_api_key,
    helm_release.aws_load_balancer_controller # CRITICAL: AWS Load Balancer Controller must be ready before Datadog creates services
  ]
}

