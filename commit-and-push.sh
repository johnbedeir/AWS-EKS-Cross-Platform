#!/bin/bash
# Script to add, commit, and push files based on git status

set -e

echo "=== Checking git status ==="
git status

echo ""
echo "=== Getting uncommitted files ==="
UNCOMMITTED_FILES=$(git status --porcelain | grep -E '^[AM]' | awk '{print $2}')

if [ -z "$UNCOMMITTED_FILES" ]; then
    echo "No uncommitted files found. Checking for untracked files..."
    UNTRACKED_FILES=$(git status --porcelain | grep '^??' | awk '{print $2}')
    if [ -z "$UNTRACKED_FILES" ]; then
        echo "No files to commit. Exiting."
        exit 0
    else
        UNCOMMITTED_FILES="$UNTRACKED_FILES"
    fi
fi

echo "Files to commit:"
echo "$UNCOMMITTED_FILES"
echo ""

# Function to generate commit message based on file
get_commit_message() {
    local file=$1
    case "$file" in
        *.gitignore)
            echo "Add .gitignore for Terraform project"
            ;;
        terraform.tfvars.example)
            echo "Remove sensitive values from tfvars example"
            ;;
        subnet-eks.tf)
            echo "Refactor EKS prod subnets to use list variables"
            ;;
        subnet-eks-gitops.tf)
            echo "Fix subnet tags for AWS Load Balancer Controller"
            ;;
        subnet-public.tf)
            echo "Add public subnets with NAT Gateway and Internet Gateway"
            ;;
        variables.tf)
            echo "Refactor subnet variables to use lists"
            ;;
        vpc.tf)
            echo "Update VPC ACLs to use new subnet structure"
            ;;
        eks.tf)
            echo "Update EKS prod module subnet references and fix IAM role"
            ;;
        eks-gitops.tf)
            echo "Update EKS GitOps module subnet references"
            ;;
        modules/eks-prod/networking.tf)
            echo "Disable private DNS for EKS endpoint to avoid conflicts"
            ;;
        modules/eks-prod/iam.tf)
            echo "Fix ArgoCD cross-cluster access IAM role name"
            ;;
        modules/eks-prod/datadog.tf)
            echo "Fix Datadog agent - remove conflicting API key setting"
            ;;
        modules/eks-gitops/networking.tf)
            echo "Disable private DNS for GitOps EKS endpoint"
            ;;
        modules/eks-gitops/argocd.tf)
            echo "Fix ArgoCD LoadBalancer - add wait=false and controller dependency"
            ;;
        modules/eks-gitops/chartmuseum.tf)
            echo "Fix Chartmuseum LoadBalancer - add wait=false"
            ;;
        modules/eks-gitops/datadog.tf)
            echo "Fix Datadog agent - remove conflicting API key setting"
            ;;
        *)
            echo "Update $file"
            ;;
    esac
}

# Commit each file
for file in $UNCOMMITTED_FILES; do
    if [ -f "$file" ]; then
        commit_msg=$(get_commit_message "$file")
        echo "Adding and committing: $file"
        git add "$file"
        git commit -m "$commit_msg"
        echo "✅ Committed: $file"
        echo ""
    else
        echo "⚠️  File not found: $file (skipping)"
        echo ""
    fi
done

echo "=== All files committed ==="
echo ""
echo "Recent commits:"
git log --oneline -10
echo ""

# Push to remote
echo "=== Pushing to remote ==="
git push
echo "✅ Successfully pushed to remote"

echo ""
echo "=== Done ==="
