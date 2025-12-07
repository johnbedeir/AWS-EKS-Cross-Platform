####################################################################################################
###                                                                                              ###
###                              AWS LOAD BALANCER CONTROLLER                                    ###
###                                                                                              ###
####################################################################################################

# Create the service account first
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  provider = kubernetes.gitops

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }

  depends_on = [aws_eks_cluster.gitops_eks]
}

# Helm release for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  provider = helm.gitops

  name             = "${local.cluster_name}-aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.13.4"
  cleanup_on_fail  = true
  namespace        = "kube-system"
  create_namespace = false

  values = [
    <<EOF
    clusterName: ${aws_eks_cluster.gitops_eks.name}
    serviceAccount:
      create: false
      name: aws-load-balancer-controller
    region: ${var.aws_region}
    vpcId: ${var.vpc_id}
    enableShield: false
    enableWaf: false
    enableWafv2: false
    enableTargetGroupBindingOnly: false
    EOF
  ]

  depends_on = [
    aws_eks_cluster.gitops_eks,
    aws_eks_node_group.gitops_prod,
    kubernetes_config_map.aws_auth,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}
