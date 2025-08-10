# Root entry for EKS + ArgoCD deployment
#
# Terraform automatically loads all .tf files in this directory. The configuration
# is split for clarity and best practices:
# - versions.tf   : Terraform and provider version constraints
# - variables.tf  : Input variables (region defaults to eu-west-1)
# - providers.tf  : AWS/Kubernetes/Helm providers wired to the created EKS cluster
# - vpc.tf        : VPC and subnets (two AZs for control plane; workers restricted to one AZ)
# - eks.tf        : EKS cluster via official module with two node groups (role=argocd, role=app)
# - argocd.tf     : ArgoCD Helm release scheduled only on nodes labeled role=argocd
# - outputs.tf    : Cluster endpoint, name, and CA certificate outputs
#
# Usage:
#   terraform init
#   terraform apply -auto-approve
#   aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}
#
# Note: This file intentionally contains only documentation comments. All resources
# are defined in the files listed above.


