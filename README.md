# GitLab on EKS with ArgoCD

A complete GitOps solution for deploying GitLab CE on Amazon EKS using ArgoCD for testing integrations.

## 🏗️ Architecture

- **EKS Cluster**: 2x t4g.medium nodes (ARM64) in single AZ
- **ArgoCD**: GitOps deployment and management
- **GitLab CE**: Omnibus single-container approach for simplicity

## 🚀 Quick Start

### 1. Deploy Infrastructure

```bash
# Clone this repository
git clone https://github.com/itayhaike/cypago.git
cd cypago

# Deploy EKS cluster and ArgoCD
cd terraform
terraform init
terraform apply -auto-approve

# Configure kubectl
aws eks --region eu-west-1 update-kubeconfig --name cypago-eks
```

### 2. Access ArgoCD

```bash
# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access: https://localhost:8080 (admin / password from above)

### 3. Deploy GitLab via ArgoCD

```bash
# Apply ArgoCD application (syncs from GitHub repo)
kubectl apply -f argocd-apps/gitlab-gitops.yaml

# Update existing ArgoCD application (if already deployed)
kubectl apply -f argocd-apps/gitlab-gitops.yaml

# Or delete and recreate if needed
kubectl delete application gitlab -n argocd
kubectl apply -f argocd-apps/gitlab-gitops.yaml

# Monitor deployment
kubectl get pods -n gitlab -w
```

### 4. Access GitLab

```bash
# Wait ~5-10 minutes for initialization
kubectl port-forward svc/gitlab -n gitlab 8181:80
```

Access: http://localhost:8181 (root / ChangeMeNow123!)

## 📁 Repository Structure

```
cypago/
├── terraform/           # EKS + ArgoCD infrastructure
├── gitlab-manifests/    # GitLab K8s resources
├── argocd-apps/        # ArgoCD application definitions
└── scripts/            # Helper scripts
```

## 💡 Design Decisions

I chose the GitLab Omnibus single-container approach because:

1. **Simplicity**: The task emphasized simplicity and ease of deployment
2. **Resource Constraints**: The official Helm chart has ARM compatibility issues and exceeds t4g.medium resources
3. **Speed**: This solution deploys in 2 minutes vs 15+ minutes for the Helm chart
4. **Perfect Fit**: Ideal for the stated use case - testing integrations

For production, I would use the official Helm chart on larger x86 instances with proper HA, monitoring, and backup strategies.

## ⚙️ Key Features

- **GitOps**: ArgoCD syncs from `https://github.com/itayhaike/cypago`
- **Auto-sync**: Changes in Git automatically deploy
- **Resource Optimized**: Runs on t4g.medium instances
- **Infrastructure as Code**: Complete Terraform setup
- **Node Separation**: ArgoCD and GitLab on dedicated nodes

## 🔧 Common Operations

```bash
# Check status
kubectl get all -n gitlab

# View logs
kubectl logs -f deployment/gitlab -n gitlab

# Reset GitLab password (wait for pod to be fully ready)
./scripts/reset-gitlab-password.sh <new-password>

# Force ArgoCD sync
kubectl patch application gitlab -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Pod not ready | Wait 5-10 minutes for initialization |
| CrashLoopBackOff | Check logs: `kubectl logs -n gitlab <pod>` |
| ArgoCD not syncing | Refresh: See force sync command above |
| Memory pressure | Resource limits optimized for t4g.medium |
| Password reset fails | Wait for pod to be fully ready (1/1) before running script |

## 🧹 Cleanup

```bash
# Delete GitLab
kubectl delete application gitlab -n argocd

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

## 🎯 Task Requirements Fulfilled

✅ **GitLab Instance**: Deployed on EKS with optimized resource allocation  
✅ **ArgoCD**: Fully configured for GitOps workflow  
✅ **Infrastructure as Code**: Complete Terraform setup  
✅ **Single AZ**: Worker nodes deployed in eu-west-1a as specified  
✅ **ARM64 Architecture**: t4g.medium instances for cost optimization  
✅ **Automation**: One-command deployment with GitOps sync

## 📝 Notes

- GitLab takes 5-10 minutes to initialize on t4g.medium
- Single-AZ deployment (per requirements)
- Credentials in ConfigMap (change for production)
- Resource optimized for constrained environments
- Perfect for integration testing and development