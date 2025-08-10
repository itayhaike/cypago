#!/bin/bash

set -e

echo "🚀 Starting GitLab on EKS deployment with ArgoCD..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { print_error "terraform is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl is required but not installed. Aborting."; exit 1; }
command -v aws >/dev/null 2>&1 || { print_error "aws cli is required but not installed. Aborting."; exit 1; }

# Deploy infrastructure
print_step "Deploying EKS cluster and ArgoCD..."
cd terraform
terraform init
terraform apply -auto-approve

print_info "Infrastructure deployed successfully!"

# Configure kubectl
print_step "Configuring kubectl..."
aws eks --region eu-west-1 update-kubeconfig --name cypago-eks

print_info "kubectl configured successfully!"

# Wait for ArgoCD to be ready
print_step "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

print_info "ArgoCD is ready!"

# Get ArgoCD admin password
print_step "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

# Deploy GitLab via ArgoCD
print_step "Deploying GitLab via ArgoCD..."
cd ..
kubectl apply -f argocd-apps/gitlab-gitops.yaml

print_info "GitLab ArgoCD application created!"

# Wait for GitLab deployment
print_step "Waiting for GitLab deployment to start..."
sleep 30
kubectl wait --for=condition=available --timeout=900s deployment/gitlab -n gitlab

print_info "GitLab deployed successfully!"

# Ask user if they want to reset GitLab password
echo ""
echo -e "${YELLOW}Would you like to reset the GitLab root password? (y/N):${NC}"
read -r RESET_PASSWORD

if [[ $RESET_PASSWORD =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Enter new password (minimum 8 characters):${NC}"
    read -s NEW_GITLAB_PASSWORD
    echo ""
    
    if [ ${#NEW_GITLAB_PASSWORD} -lt 8 ]; then
        print_error "Password must be at least 8 characters long. Skipping password reset."
    else
        print_step "Resetting GitLab password..."
        if ./scripts/reset-gitlab-password.sh "$NEW_GITLAB_PASSWORD"; then
            print_info "GitLab password reset successfully!"
            GITLAB_PASSWORD="$NEW_GITLAB_PASSWORD"
        else
            print_error "Failed to reset GitLab password. You can try manually later."
            GITLAB_PASSWORD="ChangeMeNow123!"
        fi
    fi
else
    GITLAB_PASSWORD="ChangeMeNow123!"
fi

# Display access information
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Access Information:"
echo "======================"
echo ""
echo "🔧 ArgoCD:"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo "  Command: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "🦊 GitLab:"
echo "  URL: http://localhost:8181"
echo "  Username: root"
echo "  Password: $GITLAB_PASSWORD"
echo "  Command: kubectl port-forward svc/gitlab -n gitlab 8181:80"
echo ""
echo "📊 Monitoring Commands:"
echo "  Check GitLab status: kubectl get pods -n gitlab"
echo "  Check ArgoCD apps: kubectl get applications -n argocd"
echo "  View GitLab logs: kubectl logs -f deployment/gitlab -n gitlab"
echo ""
echo "🔑 Password Reset:"
echo "  Reset GitLab password: ./scripts/reset-gitlab-password.sh <new-password>"
echo ""
echo "🧹 Cleanup:"
echo "  Delete GitLab: kubectl delete application gitlab -n argocd"
echo "  Destroy infrastructure: cd terraform && terraform destroy -auto-approve"
echo ""
print_info "GitLab will take 5-10 minutes to fully initialize. Please wait before accessing."