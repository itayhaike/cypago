# GitLab on EKS with ArgoCD

A simple GitOps solution for deploying GitLab CE on Amazon EKS using ArgoCD.

## 🏗️ Architecture

- **EKS Cluster**: 2x t4g.medium nodes (ARM64) in single AZ
- **ArgoCD**: GitOps deployment and management
- **GitLab CE**: Optimized for limited resources

## 🚀 Quick Start

### 1. Deploy Infrastructure

```bash
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
# Apply ArgoCD application (syncs from this GitHub repo)
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

## ⚙️ Key Features

- **GitOps**: ArgoCD syncs from `https://github.com/itayhaike/cypago`
- **Auto-sync**: Changes in Git automatically deploy
- **Resource Optimized**: Runs on t4g.medium instances
- **Simple Setup**: Single command deployment

## 🔧 Common Operations

```bash
# Check status
kubectl get all -n gitlab

# View logs
kubectl logs -f deployment/gitlab -n gitlab

# Reset GitLab password
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

## 🧹 Cleanup

```bash
# Delete GitLab
kubectl delete application gitlab -n argocd

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

## 📝 Notes

- GitLab takes 5-10 minutes to initialize on t4g.medium
- Single-AZ deployment (per requirements)
- Credentials in ConfigMap (change for production)