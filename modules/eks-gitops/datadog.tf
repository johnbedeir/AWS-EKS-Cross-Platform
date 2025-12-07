# Fetch existing Datadog API key from AWS Secrets Manager
data "aws_secretsmanager_secret" "datadog_api_key" {
  name = var.datadog_api_name
}

data "aws_secretsmanager_secret_version" "datadog_api_key_value" {
  secret_id = data.aws_secretsmanager_secret.datadog_api_key.id
}

resource "kubernetes_secret" "datadog_api_key" {
  count = var.enable_datadog ? 1 : 0

  provider = kubernetes.gitops

  metadata {
    name      = "${local.cluster_name}-datadog-secret"
    namespace = "kube-system"
  }

  data = {
    "api-key" = data.aws_secretsmanager_secret_version.datadog_api_key_value.secret_string
  }

  type = "Opaque"

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth
  ]
}

resource "helm_release" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0

  provider = helm.gitops

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
    name  = "datadog.kubeStateMetricsCore.enabled"
    value = "true"
  }

  set {
    name  = "datadog.kubeStateMetricsEnabled"
    value = "true"
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.eu"
  }

  set {
    name  = "agents.image.tag"
    value = "7.45.0"
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.gitops_eks.name
  }

  set {
    name  = "datadog.clusterName"
    value = aws_eks_cluster.gitops_eks.name
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "agents.useHostNetwork"
    value = "true"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.apm.enabled"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.processCollection"
    value = "true"
  }

  set {
    name  = "datadog.kubernetesKubelet.tlsVerify"
    value = "false"
  }

  set {
    name  = "datadog.kubernetesKubelet.hostCAPath"
    value = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  }

  set {
    name  = "datadog.kubernetesKubelet.tokenPath"
    value = "/var/run/secrets/kubernetes.io/serviceaccount/token"
  }

  # Disable remote config if not used
  set {
    name  = "datadog.remoteConfiguration.enabled"
    value = "false"
  }

  # Enable EC2 tag collection
  set {
    name  = "datadog.nodeLabelsAsTags"
    value = "{\"eks.amazonaws.com/nodegroup\":\"nodegroup\",\"role\":\"role\"}"
  }

  set {
    name  = "datadog.tags"
    value = "{\"env\":\"${aws_eks_cluster.gitops_eks.name}\"}"
  }

  set {
    name  = "datadog.dogstatsd.tagCardinality"
    value = "high"
  }

  set {
    name  = "datadog.collectEc2Tags"
    value = "true"
  }

  # Enhanced Kubernetes monitoring
  set {
    name  = "datadog.leaderElection"
    value = "true"
  }

  set {
    name  = "datadog.collectKubernetesEvents"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.admissionController.enabled"
    value = "true"
  }

  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = "true"
  }

  # Container monitoring
  set {
    name  = "datadog.containerExclude"
    value = "image:gcr.io/datadoghq/cluster-agent"
  }

  set {
    name  = "datadog.containerInclude"
    value = "*"
  }

  set {
    name  = "datadog.podLabelsAsTags"
    value = "{\"app\":\"app\",\"release\":\"release\",\"environment\":\"environment\"}"
  }

  set {
    name  = "clusterAgent.replicas"
    value = "2"
  }

  set {
    name  = "datadog.clusterChecks.enabled"
    value = "true"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "clusterAgent.rbac.create"
    value = "true"
  }

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth,
    kubernetes_secret.datadog_api_key
  ]
}
