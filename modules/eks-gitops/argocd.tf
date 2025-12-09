# IAM Role for ArgoCD to access external repositories
resource "aws_iam_role" "argocd_repo_access" {
  count = var.enable_argocd ? 1 : 0

  name = "${var.cluster_name}-argocd-repo-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.gitops_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-repo-server"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-argocd-repo-access"
    Environment = var.environment
    Budget      = var.proc_budget
  }
}

# IAM Policy for ArgoCD repository access
resource "aws_iam_role_policy" "argocd_repo_access" {
  count = var.enable_argocd ? 1 : 0

  name = "${var.cluster_name}-argocd-repo-access"
  role = aws_iam_role.argocd_repo_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

locals {
  argocd_values = <<EOF
    server:
      service:
        type: LoadBalancer
        port: 80
        targetPort: 8080
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: alb
          service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
          # For internet-facing ALB, use public subnets (passed from root module)
          service.beta.kubernetes.io/aws-load-balancer-subnets: ${join(",", var.public_subnet_ids)}
          # Force ALB (not NLB) by specifying backend protocol
          service.beta.kubernetes.io/aws-load-balancer-backend-protocol: HTTP
          service.beta.kubernetes.io/aws-load-balancer-target-type: ip
      extraArgs:
        - --insecure
      serviceAccount:
        create: true
        name: argocd-server
    repoServer:
      service:
        port: 8081
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-repo-server
        annotations:
          eks.amazonaws.com/role-arn: ${aws_iam_role.argocd_repo_access[0].arn}
    applicationController:
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 250m
          memory: 256Mi
      serviceAccount:
        create: true
        name: argocd-application-controller
        annotations:
          eks.amazonaws.com/role-arn: ${var.target_cluster_name != "" ? aws_iam_role.argocd_cross_cluster_access[0].arn : ""}
    rbac:
      create: true
    EOF
}

resource "helm_release" "argocd" {
  provider         = helm.gitops
  name             = "${local.cluster_name}-argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.2.4"
  cleanup_on_fail  = true
  namespace        = "argocd"
  create_namespace = true
  timeout          = 1200
  wait             = false # Don't wait for LoadBalancer to be ready (it will be created asynchronously)

  values = [local.argocd_values]

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth,
    helm_release.aws_load_balancer_controller # CRITICAL: AWS Load Balancer Controller must be ready before ArgoCD creates LoadBalancer service
  ]
}

# Create ArgoCD cluster secret for production cluster
# This allows ArgoCD to deploy applications to the production EKS cluster
# ArgoCD will use the IAM role attached to argocd-application-controller service account
# to authenticate with the production cluster via AWS IAM
resource "kubernetes_secret" "argocd_prod_cluster" {
  # Use for_each with a static key to avoid "unknown at plan time" errors
  # The key is static, so Terraform can determine the map structure even when values are unknown
  # The condition in the value will be evaluated at apply time
  for_each = var.enable_argocd ? { "prod-cluster" = true } : {}

  provider = kubernetes.gitops

  metadata {
    name      = "${replace(var.target_cluster_name != "" ? var.target_cluster_name : "prod-cluster", "-", "")}-cluster"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    # Cluster name (friendly name shown in ArgoCD UI)
    name = base64encode(var.target_cluster_name != "" ? var.target_cluster_name : "prod-cluster")

    # Production cluster endpoint
    server = base64encode(var.target_cluster_endpoint != "" ? var.target_cluster_endpoint : "")

    # Cluster configuration - ArgoCD v2+ format
    # ArgoCD will use AWS IAM authentication via the service account IAM role
    config = base64encode(jsonencode({
      # AWS IAM authentication - ArgoCD will use the IAM role from the service account
      # The role is attached to argocd-application-controller service account
      awsAuthConfig = {
        clusterName = var.target_cluster_name != "" ? var.target_cluster_name : "prod-cluster"
      }
      # TLS configuration
      tlsClientConfig = {
        # CA certificate for the production cluster (base64 encoded)
        caData = var.target_cluster_ca_data != "" ? var.target_cluster_ca_data : ""
        # Insecure skip TLS verify (set to false for production)
        insecure = false
      }
    }))
  }

  depends_on = [
    helm_release.argocd,
    aws_iam_role.argocd_cross_cluster_access
  ]
}
