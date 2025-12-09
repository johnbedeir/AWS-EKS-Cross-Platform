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
    name      = "datadog-secret"
    namespace = "kube-system"
  }

  data = {
    # Trim whitespace from API key to ensure it's properly formatted
    "api-key" = trimspace(data.aws_secretsmanager_secret_version.datadog_api_key_value.secret_string)
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

  name             = "datadog"
  namespace        = "kube-system"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = "3.116.3"
  create_namespace = false
  timeout          = 600   # Increase timeout to 10 minutes
  wait             = false # Don't wait for all pods to be ready (they may have readiness probe issues)

  # Essential configuration
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
    value = "datadoghq.com"
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.gitops_eks.name
  }

  # Cluster agent configuration
  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.replicas"
    value = "1"
  }

  # Fix readiness probe - increase initial delay and adjust thresholds
  set {
    name  = "clusterAgent.readinessProbe.initialDelaySeconds"
    value = "30"
  }

  set {
    name  = "clusterAgent.readinessProbe.periodSeconds"
    value = "10"
  }

  set {
    name  = "clusterAgent.readinessProbe.timeoutSeconds"
    value = "5"
  }

  set {
    name  = "clusterAgent.readinessProbe.failureThreshold"
    value = "6"
  }

  # Resource limits
  set {
    name  = "clusterAgent.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "clusterAgent.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "clusterAgent.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "clusterAgent.resources.limits.memory"
    value = "512Mi"
  }

  # Node agent resource limits
  set {
    name  = "agents.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "agents.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "agents.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "agents.resources.limits.memory"
    value = "512Mi"
  }

  # Fix readiness probe for node agents - more lenient settings
  set {
    name  = "agents.readinessProbe.initialDelaySeconds"
    value = "60"
  }

  set {
    name  = "agents.readinessProbe.periodSeconds"
    value = "10"
  }

  set {
    name  = "agents.readinessProbe.timeoutSeconds"
    value = "5"
  }

  set {
    name  = "agents.readinessProbe.failureThreshold"
    value = "10"
  }

  set {
    name  = "agents.readinessProbe.successThreshold"
    value = "1"
  }

  # RBAC
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
    kubernetes_secret.datadog_api_key,
    helm_release.aws_load_balancer_controller
  ]
}
