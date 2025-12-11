#!/bin/bash

####################################################################################################
###                                                                                              ###
###                              AWS CROSS PLATFORM DESTROY SCRIPT                                ###
###                                                                                              ###
###  This script destroys all infrastructure in the correct order:                                ###
###  1. Cross-Cluster Resources (ArgoCD cluster secrets, IAM roles)                              ###
###  2. Production Cluster (EKS Production cluster and its components)                          ###
###  3. GitOps Cluster (EKS GitOps cluster and its components)                                  ###
###  4. VPC Endpoints                                                                             ###
###  5. VPC and Networking (VPC, Subnets, NAT Gateway, Internet Gateway)                         ###
###  6. Secrets (Datadog API keys)                                                                ###
###  7. Final Destroy (Catch any remaining resources)                                             ###
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

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "AWS CLI is not configured or credentials are invalid"
    print_error "Please run: aws configure"
    exit 1
fi

# Confirmation prompt
echo -e "${RED}====================================================================================${NC}"
echo -e "${RED}⚠️  WARNING: This will DESTROY ALL AWS infrastructure!${NC}"
echo -e "${RED}====================================================================================${NC}"
echo ""
echo "This includes:"
echo "  - EKS Production cluster and all its resources"
echo "  - EKS GitOps cluster and all its resources"
echo "  - VPC, Subnets, NAT Gateway, Internet Gateway, VPC Endpoints"
echo "  - All IAM roles and policies"
echo "  - All Datadog secrets"
echo "  - All ArgoCD configurations"
echo ""
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

####################################################################################################
### STEP 1: Destroy Cross-Cluster Resources                                                      ###
####################################################################################################

print_step "Step 1: Destroying ArgoCD cross-cluster resources..."
echo "This includes:"
echo "  - ArgoCD cluster secret for Production cluster"
echo "  - Cross-cluster IAM roles and policies"
echo ""

# Try to destroy cross-cluster resources (may not exist if using different method)
terraform destroy -target=module.eks_gitops.kubernetes_secret.argocd_prod_cluster \
                  -auto-approve 2>&1 || print_warning "ArgoCD secret may not exist or already destroyed"

# Destroy cross-cluster IAM roles
terraform destroy -target=module.eks_gitops.aws_iam_role.argocd_cross_cluster_access \
                  -target=module.eks_gitops.aws_iam_role_policy.argocd_cross_cluster_access \
                  -target=module.eks.aws_iam_role.argocd_gitops_access \
                  -target=module.eks.aws_iam_role_policy.argocd_gitops_access \
                  -auto-approve 2>&1 || print_warning "Cross-cluster IAM roles may not exist or already destroyed"
echo ""

####################################################################################################
### STEP 2: Destroy Production Cluster                                                           ###
####################################################################################################

print_step "Step 2: Destroying EKS Production Cluster and its components..."
echo "This includes:"
echo "  - EKS Production Cluster"
echo "  - Node Groups for Production"
echo "  - IAM Roles and Policies for Production"
echo "  - VPC Endpoints for Production"
echo "  - Security Groups"
echo "  - Datadog Helm release for Production"
echo "  - RBAC configurations (aws-auth ConfigMap)"
echo ""

terraform destroy -target=module.eks \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "Production Cluster destroy failed"
    print_warning "You may need to manually clean up resources in AWS console"
    print_warning "Check for:"
    print_warning "  - LoadBalancers blocking deletion"
    print_warning "  - Node groups stuck in deleting state"
    exit 1
fi
echo ""

####################################################################################################
### STEP 3: Destroy GitOps Cluster                                                               ###
####################################################################################################

print_step "Step 3: Destroying EKS GitOps Cluster and its components..."
echo "This includes:"
echo "  - EKS GitOps Cluster"
echo "  - Node Groups for GitOps"
echo "  - IAM Roles and Policies for GitOps"
echo "  - VPC Endpoints for GitOps"
echo "  - Security Groups"
echo "  - ArgoCD, Chartmuseum, Datadog Helm releases"
echo ""

terraform destroy -target=module.eks_gitops \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "GitOps Cluster destroy failed"
    print_warning "You may need to manually clean up resources in AWS console"
    print_warning "Check for:"
    print_warning "  - LoadBalancers blocking deletion"
    print_warning "  - Node groups stuck in deleting state"
    exit 1
fi
echo ""

####################################################################################################
### STEP 4: Destroy VPC Endpoints (if created separately)                                        ###
####################################################################################################

print_step "Step 4: Destroying VPC Endpoints..."
echo "Note: VPC Endpoints are usually destroyed with clusters, but checking for any remaining..."
echo ""

# VPC endpoints are typically destroyed with the clusters, but check anyway
terraform destroy -target=module.eks.aws_vpc_endpoint.eks \
                  -target=module.eks.aws_vpc_endpoint.ecr_api \
                  -target=module.eks.aws_vpc_endpoint.ecr_dkr \
                  -target=module.eks.aws_vpc_endpoint.s3 \
                  -target=module.eks_gitops.aws_vpc_endpoint.eks \
                  -target=module.eks_gitops.aws_vpc_endpoint.ecr_api \
                  -target=module.eks_gitops.aws_vpc_endpoint.ecr_dkr \
                  -target=module.eks_gitops.aws_vpc_endpoint.s3 \
                  -auto-approve 2>&1 || print_warning "VPC Endpoints may already be destroyed or created within modules"
echo ""

####################################################################################################
### STEP 5: Destroy VPC and Networking                                                            ###
####################################################################################################

print_step "Step 5: Destroying VPC and Networking infrastructure..."
echo "This includes:"
echo "  - Route Table Associations"
echo "  - Route Tables"
echo "  - NAT Gateway"
echo "  - Internet Gateway"
echo "  - Subnets (Private and Public)"
echo "  - VPC Network"
echo ""

terraform destroy -target=aws_route_table_association.private_eks_gitops \
                  -target=aws_route_table_association.private_eks_prod \
                  -target=aws_route_table_association.public \
                  -target=aws_route_table.private \
                  -target=aws_route_table.public \
                  -target=aws_nat_gateway.main \
                  -target=aws_eip.nat_gateway \
                  -target=aws_internet_gateway.main \
                  -target=aws_subnet.private_eks_gitops \
                  -target=aws_subnet.private_eks_prod \
                  -target=aws_subnet.public \
                  -target=aws_vpc.main \
                  -auto-approve
if [ $? -ne 0 ]; then
    print_error "VPC and Networking destroy failed"
    print_warning "You may need to manually clean up resources in AWS console"
    print_warning "Check for:"
    print_warning "  - LoadBalancers using subnets"
    print_warning "  - Network interfaces attached to resources"
    print_warning "  - Security groups with dependencies"
    exit 1
fi
echo ""

####################################################################################################
### STEP 6: Destroy Secrets                                                                      ###
####################################################################################################

print_step "Step 6: Destroying AWS Secrets Manager secrets..."
echo "This includes:"
echo "  - Datadog API key secret for Production cluster"
echo "  - Datadog API key secret for GitOps cluster"
echo ""

# Check if secrets are uncommented
if grep -q "^resource \"aws_secretsmanager_secret\"" secrets.tf 2>/dev/null; then
    terraform destroy -target=aws_secretsmanager_secret_version.gitops_datadog_api_key \
                      -target=aws_secretsmanager_secret.gitops_datadog_api_key \
                      -target=aws_secretsmanager_secret_version.datadog_api_key \
                      -target=aws_secretsmanager_secret.datadog_api_key \
                      -auto-approve 2>&1 || print_warning "Secrets may not exist or already destroyed"
else
    print_warning "Secrets are commented out in secrets.tf. Skipping secret destruction."
fi
echo ""

####################################################################################################
### STEP 7: Final Destroy (Catch any remaining resources)                                        ###
####################################################################################################

print_step "Step 7: Performing final 'terraform destroy' to catch any remaining resources..."
terraform destroy -auto-approve
if [ $? -ne 0 ]; then
    print_error "Final 'terraform destroy' failed"
    print_warning "Some resources may still exist. Check AWS console for remaining resources."
    exit 1
fi
echo ""

####################################################################################################
### STEP 8: Cleanup Verification                                                                 ###
####################################################################################################

print_step "Step 8: Verifying cleanup..."

# Check for remaining EKS clusters
REMAINING_CLUSTERS=$(aws eks list-clusters --region "$AWS_REGION" --output text 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING_CLUSTERS" != "0" ]; then
    print_warning "Found remaining cluster(s):"
    aws eks list-clusters --region "$AWS_REGION" --output table 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these clusters:"
    print_warning "  aws eks delete-cluster --name <cluster-name> --region $AWS_REGION"
else
    echo "✅ No remaining EKS clusters found"
fi

# Check for remaining VPCs
REMAINING_VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=clerk-vpc-*" --region "$AWS_REGION" --query 'Vpcs[*].VpcId' --output text 2>/dev/null | wc -w)
if [ "$REMAINING_VPCS" != "0" ]; then
    print_warning "Found remaining VPC(s):"
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=clerk-vpc-*" --region "$AWS_REGION" --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these VPCs:"
    print_warning "  aws ec2 delete-vpc --vpc-id <vpc-id> --region $AWS_REGION"
else
    echo "✅ No remaining VPCs found"
fi

# Check for remaining LoadBalancers
REMAINING_LBS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].LoadBalancerArn' --output text 2>/dev/null | wc -w)
if [ "$REMAINING_LBS" != "0" ]; then
    print_warning "Found $REMAINING_LBS remaining LoadBalancer(s):"
    aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' --output table 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these LoadBalancers:"
    print_warning "  aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region $AWS_REGION"
else
    echo "✅ No remaining LoadBalancers found"
fi

# Check for remaining NAT Gateways
REMAINING_NATS=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available,pending" --region "$AWS_REGION" --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null | wc -w)
if [ "$REMAINING_NATS" != "0" ]; then
    print_warning "Found $REMAINING_NATS remaining NAT Gateway(ies):"
    aws ec2 describe-nat-gateways --filter "Name=state,Values=available,pending" --region "$AWS_REGION" --query 'NatGateways[*].[NatGatewayId,VpcId,State]' --output table 2>/dev/null
    echo ""
    print_warning "You may need to manually delete these NAT Gateways:"
    print_warning "  aws ec2 delete-nat-gateway --nat-gateway-id <id> --region $AWS_REGION"
else
    echo "✅ No remaining NAT Gateways found"
fi

# Check for remaining Elastic IPs
REMAINING_EIPS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --region "$AWS_REGION" --query 'Addresses[?AssociationId==null].AllocationId' --output text 2>/dev/null | wc -w)
if [ "$REMAINING_EIPS" != "0" ]; then
    print_warning "Found $REMAINING_EIPS unassociated Elastic IP(s):"
    aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --region "$AWS_REGION" --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]' --output table 2>/dev/null
    echo ""
    print_warning "You may need to manually release these Elastic IPs:"
    print_warning "  aws ec2 release-address --allocation-id <id> --region $AWS_REGION"
else
    echo "✅ No remaining unassociated Elastic IPs found"
fi

echo ""
print_step "Destroy process completed!"
echo ""
echo "📝 Next steps:"
echo "  1. Verify all resources are deleted in AWS console"
echo "  2. Check for any remaining resources and delete manually if needed"
echo "  3. Run 'terraform init' if you want to rebuild"
echo ""

