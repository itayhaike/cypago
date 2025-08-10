# GitLab on EKS with ArgoCD - DevOps Assignment

This repository contains a complete solution for deploying GitLab Community Edition on Amazon EKS using ArgoCD for GitOps deployment. The solution is designed to be simple, repeatable, and suitable for testing integrations.

## 🏗️ Architecture Overview

- **EKS Cluster**: Single-AZ deployment with two t4g.medium ARM64 nodes
- **ArgoCD**: GitOps deployment tool for managing GitLab
- **GitLab CE**: Minimal configuration optimized for t4g.medium resources
- **Node Separation**: ArgoCD and GitLab run on separate nodes

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm (for ArgoCD)

## 🚀 Quick Start

### 1. Deploy Infrastructure

```bash
# Clone repository
git clone <repository-url>
cd cypago

# Deploy EKS cluster and ArgoCD
cd terraform
terraform init
terraform apply -auto-approve

# Configure kubectl
aws eks --region eu-west-1 update-kubeconfig --name cypago-eks
```

### 2. Verify ArgoCD Deployment

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Get ArgoCD admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI (in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Visit https://localhost:8080 and login with:
- Username: `admin`
- Password: (from command above)

### 3. Deploy GitLab

#### Option A: Using Git Repository (Recommended for ArgoCD)

1. **Push this repository to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/cypago
   git push -u origin main
   ```

2. **Update ArgoCD application with your repo URL:**
   ```bash
   # Edit argocd-apps/gitlab-gitops.yaml
   # Replace YOUR_USERNAME with your GitHub username
   sed -i '' 's/YOUR_USERNAME/<your-github-username>/g' argocd-apps/gitlab-gitops.yaml
   ```

3. **Deploy GitLab via ArgoCD:**
   ```bash
   kubectl apply -f argocd-apps/gitlab-gitops.yaml
   ```

#### Option B: Direct Deployment (Without Git)

```bash
# Deploy GitLab directly
kubectl apply -f argocd-apps/gitlab-direct.yaml

# Monitor deployment
kubectl get pods -n gitlab -w
```

### 4. Access GitLab

```bash
# Wait for GitLab to be ready (5-10 minutes)
kubectl get pods -n gitlab

# Access GitLab UI (in separate terminal)
kubectl port-forward svc/gitlab -n gitlab 8181:80
```

Visit http://localhost:8181 and login with:
- Username: `root`
- Password: `ChangeMeNow123!`

## 📁 Repository Structure

```
cypago/
├── terraform/                 # Infrastructure as Code
│   ├── eks.tf                # EKS cluster configuration
│   ├── argocd.tf             # ArgoCD Helm deployment
│   ├── vpc.tf                # VPC and networking
│   └── variables.tf          # Configuration variables
├── argocd-apps/              # ArgoCD applications
│   └── gitlab-simple.yaml   # GitLab application manifest
└── scripts/                  # Operational scripts
    └── reset-gitlab-password.sh
```

## ⚙️ Configuration Details

### EKS Cluster
- **Region**: eu-west-1
- **Node Groups**: 2x t4g.medium (ARM64) in single AZ
- **Networking**: Public subnets only for simplicity

### GitLab Configuration
- **Resource Limits**: 3.5Gi memory, 1.5 CPU
- **Resource Requests**: 2.5Gi memory, 0.5 CPU
- **Optimizations**: Disabled monitoring, minimal workers
- **Storage**: EmptyDir (10Gi limit)

### ArgoCD Configuration
- **Namespace**: argocd
- **Node Affinity**: Dedicated node with `role=argocd`
- **Version**: Helm chart 6.11.0

## 🔧 Operational Commands

### GitLab Management

```bash
# Check GitLab status
kubectl get all -n gitlab

# View GitLab logs
kubectl logs -f deployment/gitlab -n gitlab

# Reset root password
./scripts/reset-gitlab-password.sh <new-password>

# Scale GitLab (if needed)
kubectl scale deployment gitlab -n gitlab --replicas=0
kubectl scale deployment gitlab -n gitlab --replicas=1
```

### ArgoCD Management

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Sync application
kubectl patch application gitlab -n argocd --type merge -p '{"operation":{"sync":{}}}'

# Access ArgoCD CLI
argocd login localhost:8080
argocd app list
```

## 🐛 Troubleshooting

### GitLab Not Starting

1. **Check pod status and events**:
   ```bash
   kubectl describe pod -l app=gitlab -n gitlab
   ```

2. **Check resource constraints**:
   ```bash
   kubectl top nodes
   kubectl describe node | grep -A 5 "Allocated resources"
   ```

3. **View initialization logs**:
   ```bash
   kubectl logs -f deployment/gitlab -n gitlab
   ```

### Common Issues

| Issue | Symptom | Solution |
|-------|---------|----------|
| Pod stuck in Pending | Node resources | Check node capacity |
| Readiness probe fails | 0/1 Ready | Wait 5-10 minutes for initialization |
| Image pull errors | ErrImagePull | Verify node internet access |
| OOM kills | Pod restarts | Increase memory limits |

### GitLab Startup Timeline

- **0-2 min**: Container start, basic services
- **2-5 min**: Database migrations, configuration
- **5-10 min**: Application preload, readiness check
- **10+ min**: Fully operational

## 🧪 Testing Integration

### Verify GitLab API

```bash
# Test GitLab API
kubectl exec -n gitlab deployment/gitlab -- curl -s http://localhost:80/api/v4/version

# Create test project via API
curl -X POST http://localhost:8181/api/v4/projects \
  -H "Private-Token: <access-token>" \
  -d "name=test-project"
```

### Load Testing

```bash
# Simple load test
kubectl run load-test --image=busybox --rm -it --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://gitlab.gitlab.svc.cluster.local; sleep 1; done'
```

## 🔄 Multi-Cluster Deployment

To deploy on multiple clusters:

1. **Update variables**:
   ```bash
   # In terraform/variables.tf
   variable "cluster_name" { default = "cypago-eks-prod" }
   variable "region" { default = "us-west-2" }
   ```

2. **Deploy with different workspace**:
   ```bash
   terraform workspace new production
   terraform apply -auto-approve
   ```

3. **Update ArgoCD application**:
   ```bash
   # Modify argocd-apps/gitlab-simple.yaml
   # Change namespace or add environment-specific values
   ```

## 📊 Monitoring and Metrics

### Basic Monitoring

```bash
# Pod resource usage
kubectl top pods -n gitlab

# Service endpoints
kubectl get endpoints -n gitlab

# Events
kubectl get events -n gitlab --sort-by='.lastTimestamp'
```

### Performance Tuning

For production workloads, consider:
- Using larger instance types (t4g.large or c6g.medium)
- Adding persistent volumes for data persistence
- Enabling GitLab monitoring (requires more resources)
- Using external PostgreSQL and Redis

## 🧹 Cleanup

```bash
# Delete GitLab application
kubectl delete -f argocd-apps/gitlab-simple.yaml

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

## 📝 Notes

- GitLab initialization takes 5-10 minutes on t4g.medium instances
- The configuration is optimized for ARM64 architecture
- Single-AZ deployment is used per requirements (not recommended for production)
- Root password is set in ConfigMap (change for production use)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test
4. Submit a pull request

## 📄 License

This project is provided as-is for educational and testing purposes.