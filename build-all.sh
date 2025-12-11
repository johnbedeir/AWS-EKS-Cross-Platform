#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              AWS CROSS PLATFORM BUILD SCRIPT                                  ###
###                                                                                              ###
###  This script builds all infrastructure in the correct order:                                 ###
###  1. Terraform Initialization                                                                 ###
###  2. Secrets (Datadog API keys)                                                               ###
###  3. VPC and Networking (VPC, Subnets, NAT Gateway, Internet Gateway, VPC Endpoints)         ###
###  4. GitOps Cluster (EKS GitOps cluster with ArgoCD)                                          ###
###  5. Production Cluster (EKS Production cluster)                                             ###
###  6. Final Apply (Catch any remaining resources)                                              ###
###  7. Get Cluster Information                                                                  ###
###                                                                                              ###
####################################################################################################

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print steps
print_step() {
    echo -e "\n${GREEN}====================================================================================${NC}"
    echo -e "${GREEN}[STEP]${NC} $1"
    echo -e "${GREEN}====================================================================================${NC}"
}

# Function to print errors
print_error() {
    echo -e "\n${RED}[ERROR]${NC} $1" >&2
}

# Function to print warnings
print_warning() {
    echo -e "\n${YELLOW}[WARNING]${NC} $1"
}

# Change to the Terraform directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
cd "$SCRIPT_DIR"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run: aws configure"
    exit 1
fi

# Get AWS account ID and region from Terraform or AWS CLI
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "Could not determine AWS Account ID"
    exit 1
fi

print_step "AWS Configuration"
echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

####################################################################################################
### STEP 1: Initialize Terraform                                                                 ###
####################################################################################################

print_step "Step 1: Initializing Terraform..."
terraform init
if [ $? -ne 0 ]; then
    print_error "Terraform initialization failed"
    exit 1
fi
echo ""

####################################################################################################
### STEP 2: Create Secrets (if configured)                                                       ###
####################################################################################################

# Note: Secrets may be commented out in secrets.tf
# If you need Datadog secrets, uncomment them in secrets.tf first
print_step "Step 2: Checking for secrets configuration..."
if grep -q "^resource \"aws_secretsmanager_secret\"" secrets.tf 2>/dev/null; then
    echo "Creating AWS Secrets Manager secrets..."
    echo "This includes:"
    echo "  - Datadog API key secret for Production cluster"
    echo "  - Datadog API key secret for GitOps cluster"
    echo ""
    terraform apply -target=aws_secretsmanager_secret.datadog_api_key \
                    -target=aws_secretsmanager_secret_version.datadog_api_key \
                    -target=aws_secretsmanager_secret.gitops_datadog_api_key \
                    -target=aws_secretsmanager_secret_version.gitops_datadog_api_key \
                    -auto-approve 2>&1 || print_warning "Secrets may be commented out or already exist"
else
    print_warning "Secrets are commented out in secrets.tf. Skipping secret creation."
    echo "If you need Datadog, uncomment the secrets in secrets.tf and run this step again."
fi
echo ""

####################################################################################################
### STEP 3: Build VPC and Networking                                                             ###
####################################################################################################

print_step "Step 3: Building VPC and Networking infrastructure..."
echo "This includes:"
echo "  - VPC Network"
echo "  - Private Subnets for EKS Prod and GitOps"
echo "  - Public Subnets for NAT Gateway and Load Balancers"
echo "  - Internet Gateway"
echo "  - NAT Gateway"
echo "  - Route Tables"
echo "  - VPC Endpoints (EKS, ECR, S3)"
echo ""

terraform apply -target=aws_vpc.main \
                -target=aws_subnet.private_eks_prod \
                -target=aws_subnet.private_eks_gitops \
                -target=aws_subnet.public \
                -target=aws_internet_gateway.main \
                -target=aws_eip.nat_gateway \
                -target=aws_nat_gateway.main \
                -target=aws_route_table.public \
                -target=aws_route_table.private \
                -target=aws_route_table_association.public \
                -target=aws_route_table_association.private_eks_prod \
                -target=aws_route_table_association.private_eks_gitops \
                -auto-approve
if [ $? -ne 0 ]; then
    print_error "VPC and Networking build failed"
    exit 1
fi
echo ""

# Note: VPC Endpoints are created within the EKS modules
# They will be created automatically when the clusters are built

####################################################################################################
### STEP 4: Build GitOps Cluster                                                                 ###
####################################################################################################

print_step "Step 4: Building EKS GitOps Cluster and its components..."
echo "This includes:"
echo "  - EKS GitOps Cluster"
echo "  - Node Groups for GitOps"
echo "  - IAM Roles and Policies for GitOps"
echo "  - VPC Endpoints for GitOps"
echo "  - Security Groups"
echo "  - ArgoCD, Chartmuseum, Datadog Helm releases"
echo ""

terraform apply -target=module.eks_gitops \
                -auto-approve
if [ $? -ne 0 ]; then
    print_error "GitOps Cluster build failed"
    exit 1
fi
echo ""

# Get credentials for GitOps cluster
print_step "Getting credentials for GitOps cluster..."
GITOPS_CLUSTER_NAME=$(terraform output -raw gitops_cluster_name 2>/dev/null || echo "eks-gitops-production")
aws eks update-kubeconfig --name "$GITOPS_CLUSTER_NAME" --region "$AWS_REGION" 2>&1
if [ $? -ne 0 ]; then
    print_error "Failed to get GitOps cluster credentials"
    exit 1
fi
echo ""

# Wait for ArgoCD to be ready
print_step "Waiting for ArgoCD to be ready..."
echo "This may take 2-3 minutes..."
sleep 30
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || print_warning "ArgoCD may still be initializing"
echo ""

####################################################################################################
### STEP 5: Build Production Cluster                                                             ###
####################################################################################################

print_step "Step 5: Building EKS Production Cluster and its components..."
echo "This includes:"
echo "  - EKS Production Cluster"
echo "  - Node Groups for Production"
echo "  - IAM Roles and Policies for Production"
echo "  - VPC Endpoints for Production"
echo "  - Security Groups"
echo "  - Datadog Helm release for Production"
echo "  - RBAC for admin users and ArgoCD access"
echo ""

terraform apply -target=module.eks \
                -auto-approve
if [ $? -ne 0 ]; then
    print_error "Production Cluster build failed"
    exit 1
fi
echo ""

# Get credentials for Prod cluster
print_step "Getting credentials for Production cluster..."
PROD_CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "eks-prod-production")
aws eks update-kubeconfig --name "$PROD_CLUSTER_NAME" --region "$AWS_REGION" 2>&1
if [ $? -ne 0 ]; then
    print_error "Failed to get Production cluster credentials"
    exit 1
fi
echo ""

####################################################################################################
### STEP 6: Final Apply (Catch any remaining resources)                                          ###
####################################################################################################

print_step "Step 6: Performing final 'terraform apply' to catch any remaining resources..."
terraform apply -auto-approve
if [ $? -ne 0 ]; then
    print_error "Final 'terraform apply' failed"
    exit 1
fi
echo ""

####################################################################################################
### STEP 7: Get Cluster Information                                                              ###
####################################################################################################

print_step "Step 7: Retrieving cluster information..."

GITOPS_CLUSTER=$(terraform output -raw gitops_cluster_name 2>/dev/null || echo "eks-gitops-production")
GITOPS_ENDPOINT=$(aws eks describe-cluster --name "$GITOPS_CLUSTER" --region "$AWS_REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "N/A")

echo "GitOps Cluster:"
echo "  Name: $GITOPS_CLUSTER"
echo "  Region: $AWS_REGION"
echo "  Endpoint: $GITOPS_ENDPOINT"
echo ""

PROD_CLUSTER=$(terraform output -raw cluster_name 2>/dev/null || echo "eks-prod-production")
PROD_ENDPOINT=$(aws eks describe-cluster --name "$PROD_CLUSTER" --region "$AWS_REGION" --query 'cluster.endpoint' --output text 2>/dev/null || echo "N/A")

echo "Production Cluster:"
echo "  Name: $PROD_CLUSTER"
echo "  Region: $AWS_REGION"
echo "  Endpoint: $PROD_ENDPOINT"
echo ""

# ArgoCD LoadBalancer
print_step "Getting ArgoCD LoadBalancer information..."
aws eks update-kubeconfig --name "$GITOPS_CLUSTER" --region "$AWS_REGION" --quiet 2>&1
ARGOCD_LB=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -n "$ARGOCD_LB" ]; then
    echo "ArgoCD LoadBalancer: $ARGOCD_LB"
    echo ""
    echo "Access ArgoCD UI at: https://$ARGOCD_LB"
else
    print_warning "ArgoCD LoadBalancer not ready yet"
fi

echo ""
print_step "To access ArgoCD, wait for the LoadBalancer and then:"
echo "  kubectl get svc -n argocd argocd-server"
echo ""
echo "To get ArgoCD admin password:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""

print_step "Build process completed!"
echo ""
echo "Next steps:"
echo "  1. Wait for ArgoCD LoadBalancer to get a hostname (if not ready)"
echo "  2. Access ArgoCD UI using the LoadBalancer hostname"
echo "  3. Verify the production cluster appears in ArgoCD (Settings > Clusters)"
echo "  4. Start deploying applications!"
echo ""

