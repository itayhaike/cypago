# GitLab on EKS with ArgoCD

A complete GitOps solution for deploying GitLab CE on Amazon EKS using ArgoCD for testing integrations.

## 🏗️ Architecture

- **EKS Cluster**: 2x t4g.medium nodes (ARM64) in single AZ
- **ArgoCD**: GitOps deployment and management
- **GitLab CE**: Omnibus single-container approach for simplicity

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

**Short explanation**: The `deploy.sh` script automates the entire deployment process - creates infrastructure via Terraform, configures kubectl, deploys ArgoCD, creates the GitLab application, waits for readiness, and optionally resets the GitLab password. This is the simplest way to get a complete working environment.

```bash
# Clone this repository
git clone https://github.com/itayhaike/cypago.git
cd cypago

# Run the automated deployment script
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Deploy EKS cluster and ArgoCD via Terraform
2. Configure kubectl automatically  
3. Wait for ArgoCD to be ready
4. Deploy GitLab via ArgoCD
5. Provide access credentials and port-forward commands
6. Optionally reset GitLab password

### Option 2: Manual Step-by-Step Deployment

### 1. Deploy Infrastructure

Short explanation: Creates an EKS cluster with two t4g.medium nodes in a single worker AZ, split into dedicated node groups (`argocd` and `app`). VPC spans two subnets for the control plane, while worker nodes are restricted to one AZ, matching the requirement.

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

### 2. Deploy ArgoCD on this cluster using Terraform. The ArgoCD should be on its own namespace, and all of its pods should be deployed on only one of the nodes.

ArgoCD is installed by Terraform (via Helm) into the `argocd` namespace and constrained to nodes labeled `role=argocd`.

Short explanation: Helm values set `nodeSelector: role=argocd` for all ArgoCD components (controller, repo-server, server, applicationSet, dex, redis, notifications). The `argocd` node group is a single-node group in the single AZ, so all ArgoCD pods land on that one node, satisfying “all of its pods on only one of the nodes”.

Verify and access:

```bash
# Verify namespace and pods
kubectl get ns argocd
kubectl get pods -n argocd -o wide

# (Optional) confirm all pods are on the argocd node group
kubectl get pods -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Get admin password for the UI
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access: https://localhost:8080 (username: admin, password: from the command above)

### 3. Deploy a minimal GitLab server on the cluster using ArgoCD. The GitLab should be functional. Port forwarding it out of the cluster is enough in terms of exposing it.

Short explanation: Deploys a minimal GitLab Omnibus instance pinned to the `app` node group via `nodeSelector: role=app`, with resources tuned to fit t4g.medium. Exposure is via `kubectl port-forward`, which is sufficient per the task.

#### Option A: CLI (kubectl apply)

```bash
# Apply ArgoCD application (syncs from GitHub repo)
kubectl apply -f argocd-apps/gitlab.yaml

# Update existing ArgoCD application (if already deployed)
kubectl apply -f argocd-apps/gitlab.yaml

# Or delete and recreate if needed
kubectl delete application gitlab -n argocd
kubectl apply -f argocd-apps/gitlab.yaml

# Monitor deployment
kubectl get pods -n gitlab -w

# Expose with port-forward (sufficient for this task)
# Wait ~5-10 minutes for initialization
kubectl port-forward svc/gitlab -n gitlab 8181:80
```

Access GitLab: http://localhost:8181 (initial credentials set in manifests; see notes below)

#### Option B: ArgoCD UI (paste YAML)

- Open the ArgoCD UI at `https://localhost:8080` and sign in (see step 2 above)
- Click "New App" / "Create Application"
- Switch to the YAML editor and paste the following, then click "Create":

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitlab
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/itayhaike/cypago
    targetRevision: HEAD
    path: gitlab-manifests  # Path to the manifests directory in your repo
  destination:
    server: https://kubernetes.default.svc
    namespace: gitlab
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

After the application is created, open it in ArgoCD and click "Sync" if it does not auto-sync.

### 4. Add a simple script that resets the Gitlab password. Change the password to a user-given password.

Short explanation: The script runs `gitlab-rails` inside the GitLab pod to set the `root` password to a user-provided value, after verifying the pod is Ready and with a timeout for reliability.

Use the provided script to reset the `root` password inside the GitLab pod:

```bash
# Wait until the GitLab pod is Ready (1/1), then run:
./scripts/reset-gitlab-password.sh 'MyNewSecurePassword123!'
```

If successful, sign in at `http://localhost:8181` with:

- Username: `root`
- Password: the value you provided

**LoadBalancer Access (External):**
```bash
# Get the external URL (takes 2-3 minutes to provision)
kubectl get svc gitlab -n gitlab

# Access via the EXTERNAL-IP
# Example: http://a1234567890abcdef-1234567890.eu-west-1.elb.amazonaws.com
```

**Port-forward Access (Local):**
```bash
# Alternative local access method
kubectl port-forward svc/gitlab -n gitlab 8181:80
```

Access: External LoadBalancer URL or http://localhost:8181 (root / ChangeMeNow123!)

## 📁 Repository Structure

```
  cypago/
  ├── terraform/           # Infrastructure
  ├── gitlab-manifests/    # GitLab K8s resources
  │   ├── configmap.yaml   # GitLab configuration
  │   ├── deployment.yaml  # GitLab deployment with PVCs
  │   ├── namespace.yaml   # Namespace definition
  │   ├── pvc.yaml         # Persistent Volume Claims
  │   └── service.yaml     # LoadBalancer service
  ├── argocd-apps/
  │   └── gitlab.yaml      # Single ArgoCD application
  ├── scripts/
  │   └── reset-gitlab-password.sh
  ├── deploy.sh           # Automation
  └── README.md          # Documentation
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
- **LoadBalancer Exposure**: External access via AWS Load Balancer
- **Persistent Storage**: Data survives pod restarts with EBS volumes

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

## 🏆 Optional Bonuses Implemented

✅ **LoadBalancer Exposure**: External access via AWS ALB/NLB  
✅ **Persistent Storage**: EBS volumes for data persistence across pod restarts

## 📝 Notes

- GitLab takes 5-10 minutes to initialize on t4g.medium
- Single-AZ deployment (per requirements)
- Credentials in ConfigMap (change for production)
- Resource optimized for constrained environments
- Perfect for integration testing and development

## 🙌 Acknowledgements

I used Claude (AI) to assist with parts of this home assignment and referenced the official GitLab Omnibus documentation. Using AI tools is part of my workflow—and, I believe, the future of engineering productivity. 🙂