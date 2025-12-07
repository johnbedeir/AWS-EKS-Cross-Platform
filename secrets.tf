# ####################################################################################################
# ###                                                                                              ###
# ###                                    AWS Secrets Manager                                       ###
# ###                                                                                              ###
# ####################################################################################################

# # Datadog API Key Secret for EKS Production Cluster
# resource "aws_secretsmanager_secret" "datadog_api_key" {
#   name        = var.datadog_api_name
#   description = "Datadog API key for EKS production cluster monitoring"

#   tags = {
#     Name = var.datadog_api_name
#   }
# }

# resource "aws_secretsmanager_secret_version" "datadog_api_key" {
#   secret_id     = aws_secretsmanager_secret.datadog_api_key.id
#   secret_string = var.datadog_api_key_value

#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

# # Datadog API Key Secret for EKS GitOps Cluster
# resource "aws_secretsmanager_secret" "gitops_datadog_api_key" {
#   name        = var.gitops_datadog_api_name
#   description = "Datadog API key for EKS GitOps cluster monitoring"

#   tags = {
#     Name = var.gitops_datadog_api_name
#   }
# }

# resource "aws_secretsmanager_secret_version" "gitops_datadog_api_key" {
#   secret_id     = aws_secretsmanager_secret.gitops_datadog_api_key.id
#   secret_string = var.gitops_datadog_api_key_value

#   lifecycle {
#     ignore_changes = [secret_string]
#   }
# }

