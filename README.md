# AWS-EKS-Cross-Platform

<img src=cover.png>

A Terraform-based infrastructure as code project for deploying Amazon Elastic Kubernetes Service (EKS) clusters with GitOps capabilities using ArgoCD. This project creates two EKS clusters: a Production cluster and a GitOps cluster for managing deployments.

## 🏗️ Architecture

- **Production Cluster (`eks-prod-production`)**: Main cluster for running production workloads
- **GitOps Cluster (`eks-gitops-production`)**: Cluster running ArgoCD for GitOps-based deployments
- **VPC Network**: Private networking with NAT Gateway for outbound internet access
- **IAM Roles**: AWS IAM integration for secure authentication and authorization
- **ArgoCD**: GitOps tool for continuous deployment from Git repositories

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- AWS Account with appropriate permissions
- Required AWS services enabled:
  - EKS (Elastic Kubernetes Service)
  - EC2 (for VPC, subnets, NAT Gateway)
  - IAM (for roles and policies)
  - Secrets Manager (for Datadog API keys)

## 🚀 Quick Start

### 1. Configure Terraform Variables

Copy the example variables file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:

- `aws_account_id`: Your AWS Account ID
- `admin_users`: Your AWS IAM usernames (not full ARNs, just usernames)
- `datadog_api_key_value`: Your Datadog API key (if using Datadog)

### 2. Deploy Infrastructure

Run the build script to deploy all infrastructure in the correct order:

```bash
./build-all.sh
```

This script will:

1. Initialize Terraform
2. Create AWS Secrets Manager secrets (Datadog API keys)
3. Build VPC and networking infrastructure (VPC, subnets, NAT Gateway, Internet Gateway, route tables)
4. Create VPC Endpoints (EKS, ECR, S3)
5. Deploy GitOps cluster with ArgoCD, Chartmuseum, and Datadog
6. Deploy Production cluster with Datadog
7. Get cluster credentials and display cluster information

**Expected time:** 20-30 minutes

### 3. Configure ArgoCD Cross-Cluster Access

After the build completes, ArgoCD should automatically be configured to access the Production cluster via the IAM roles created. However, you may need to verify the cluster connection:

1. Access ArgoCD UI (see Step 4 below)
2. Go to **Settings** → **Clusters**
3. Verify `eks-prod-production` cluster is listed and shows as "Connected"
4. If not connected, check the cluster secret:

```bash
# Switch to GitOps cluster
aws eks update-kubeconfig --name eks-gitops-production --region us-east-1

# Check cluster secret
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster

# Restart ArgoCD controller if needed
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Wait 30 seconds** for the ArgoCD controller to restart.

### 4. Access ArgoCD UI

Get the ArgoCD LoadBalancer URL:

```bash
# Switch to GitOps cluster
aws eks update-kubeconfig --name eks-gitops-production --region us-east-1

# Get LoadBalancer URL
kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD UI at `https://<LOADBALANCER_HOSTNAME>` (use the password from above, username is `admin`)

## 🧪 Testing with Hello World Helm Chart

### Step 1: Authenticate with Clusters

Authenticate with both clusters to verify access:

```bash
# Authenticate with Production cluster
aws eks update-kubeconfig --name eks-prod-production --region us-east-1

# Authenticate with GitOps cluster
aws eks update-kubeconfig --name eks-gitops-production --region us-east-1
```

### Step 2: Create Namespace on Production Cluster

Switch to the Production cluster context and create a test namespace:

```bash
# Ensure you're using the prod cluster
aws eks update-kubeconfig --name eks-prod-production --region us-east-1

# Create test namespace
kubectl create namespace test
```

### Step 3: Add Helm Repository in ArgoCD

1. Open ArgoCD UI (from Step 4 above)
2. Go to **Settings** → **Repositories**
3. Click **Connect Repo**
4. Fill in:
   - **Type**: Helm
   - **Name**: `hello-world` (or any name)
   - **URL**: `https://charts.bitnami.com/bitnami` (Bitnami charts repository)
   - **Enable OCI**: Leave unchecked
5. Click **Connect**

### Step 4: Create Application in ArgoCD

1. In ArgoCD UI, click **New App** or the **+** button
2. Fill in the application details:

   **General:**

   - **Application Name**: `hello-world`
   - **Project Name**: `default`
   - **Sync Policy**: `Manual` or `Automatic`

   **Source:**

   - **Repository**: Select the repository you just added in Step 3 from the dropdown (e.g., `hello-world` or the name you used)
     - The repository should appear in the dropdown since you connected it in Step 3
     - If it doesn't appear, go back to **Settings** → **Repositories** and verify it's connected
   - **Chart**: `nginx` (or any chart from Bitnami)
   - **Version**: `*` (latest) or specific version like `15.0.0`
   - **Helm**: Leave default values or add custom values

   **Destination:**

   - **Cluster URL**: Select the Production cluster (`eks-prod-production` or its endpoint) from the dropdown
     - If the Production cluster doesn't appear in the dropdown:
       - Go to **Settings** → **Clusters**
       - Verify `eks-prod-production` cluster is listed and shows as "Connected"
       - If not connected, check IAM roles and restart ArgoCD controller
   - **Namespace**: `test` (the namespace you created on Production cluster)

3. Click **Create**
4. Click **Sync** to deploy the application to the Production cluster

### Step 5: Verify Deployment

Check the application status in ArgoCD UI or via CLI:

```bash
# Switch to GitOps cluster
aws eks update-kubeconfig --name eks-gitops-production --region us-east-1

# Check application status
kubectl get application hello-world -n argocd

# Switch to Production cluster and verify pods
aws eks update-kubeconfig --name eks-prod-production --region us-east-1
kubectl get pods -n test
kubectl get svc -n test
```

## 🗑️ Destroy Infrastructure

To destroy all infrastructure:

```bash
./destroy-all.sh
```

This script will:

1. Ask for confirmation (type `yes` to confirm)
2. Destroy ArgoCD cross-cluster resources (secrets, IAM roles)
3. Destroy Production cluster and node groups
4. Destroy GitOps cluster and node groups
5. Destroy VPC Endpoints
6. Destroy VPC and networking (route tables, NAT Gateway, Internet Gateway, subnets, VPC)
7. Destroy secrets in AWS Secrets Manager
8. Perform final cleanup
9. Verify all resources are deleted

**Warning:** This will delete all resources. Make sure you have backups if needed.

**Note:** If you encounter dependency errors during destroy (e.g., LoadBalancers blocking subnet deletion), the script will provide manual cleanup instructions. You may need to manually delete LoadBalancers first:

```bash
# List LoadBalancers
aws elbv2 describe-load-balancers --region us-east-1

# Delete LoadBalancers if needed
aws elbv2 delete-load-balancer --load-balancer-arn <ARN> --region us-east-1
```

## 📁 Project Structure

```
AWS_Cross_Platform/
├── modules/
│   ├── eks-prod/          # Production EKS cluster module
│   │   ├── eks.tf         # EKS cluster definition
│   │   ├── node_group.tf  # Node group configuration
│   │   ├── iam.tf         # IAM roles and policies
│   │   ├── eks_auth.tf    # Kubernetes RBAC (aws-auth ConfigMap)
│   │   ├── networking.tf  # VPC endpoints and security groups
│   │   ├── datadog.tf     # Datadog agent
│   │   └── ...
│   └── eks-gitops/        # GitOps EKS cluster module
│       ├── eks.tf         # EKS cluster definition
│       ├── node_group.tf  # Node group configuration
│       ├── argocd.tf      # ArgoCD Helm release
│       ├── chartmuseum.tf # Chartmuseum Helm release
│       ├── datadog.tf     # Datadog agent
│       ├── cross_cluster.tf # Cross-cluster IAM roles
│       └── ...
├── vpc.tf                 # VPC network definition
├── subnet-eks.tf          # Production EKS subnets
├── subnet-eks-gitops.tf   # GitOps EKS subnets
├── subnet-public.tf       # Public subnets
├── eks.tf                 # Production cluster module call
├── eks-gitops.tf          # GitOps cluster module call
├── secrets.tf             # AWS Secrets Manager secrets
├── terraform.tfvars       # Variable values (not in git)
├── terraform.tfvars.example  # Example variables file
├── build-all.sh           # Build script
└── destroy-all.sh          # Destroy script
```

## 🔧 Configuration

### Node Group Sizes

Default configuration:

- **Production**: 1 node (varies by instance type in `terraform.tfvars`)
- **GitOps**: 2 nodes (varies by instance type in `terraform.tfvars`)

Adjust in `terraform.tfvars`:

- `node_group_new_desired_size`: Production desired nodes
- `node_group_new_min_size`: Production minimum nodes
- `node_group_new_max_size`: Production maximum nodes
- `gitops_node_group_desired_size`: GitOps desired nodes
- `gitops_node_group_min_size`: GitOps minimum nodes
- `gitops_node_group_max_size`: GitOps maximum nodes

### Networking

- **VPC CIDR**: `10.0.0.0/16`
- **Production Subnets**: `10.0.1.0/24`, `10.0.2.0/24` (256 IPs each)
- **GitOps Subnets**: `10.0.10.0/24`, `10.0.11.0/24` (256 IPs each)
- **Public Subnets**: `10.0.101.0/24`, `10.0.102.0/24` (for NAT Gateway and LoadBalancers)

### Cluster Access

Clusters use private networking with VPC endpoints for AWS API access. Nodes have private IPs only. Access to clusters is controlled via IAM and the `aws-auth` ConfigMap.

## 🔐 Security

- **Private Subnets**: Nodes have private IPs only
- **VPC Endpoints**: Private access to AWS services (EKS, ECR, S3)
- **IAM Roles**: Kubernetes Service Accounts mapped to AWS IAM roles via IRSA (IAM Roles for Service Accounts)
- **Security Groups**: Network-level security controls
- **RBAC**: Kubernetes RBAC configured via `aws-auth` ConfigMap
- **Secrets**: Datadog API keys stored in AWS Secrets Manager

## 📊 Monitoring

- **Datadog**: Monitoring agent deployed on both clusters
- **CloudWatch**: Automatic log collection via Fluent Bit (if configured)
- **Metrics Server**: Resource metrics for autoscaling

## 🔗 Useful Commands

```bash
# Get cluster endpoints
aws eks describe-cluster --name eks-prod-production --region us-east-1 --query 'cluster.endpoint'
aws eks describe-cluster --name eks-gitops-production --region us-east-1 --query 'cluster.endpoint'

# Update kubeconfig for clusters
aws eks update-kubeconfig --name eks-prod-production --region us-east-1
aws eks update-kubeconfig --name eks-gitops-production --region us-east-1

# List all nodes
kubectl get nodes

# Check ArgoCD applications
kubectl get applications -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Check aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# List IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `eks`)].RoleName'
```
