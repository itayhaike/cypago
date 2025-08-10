module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.kubernetes_version
  cluster_endpoint_public_access  = true
  enable_irsa                     = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Note: access_entries was removed to avoid unsupported args in future module versions

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets       # Cluster subnets (requires >= two AZs for control plane)

  eks_managed_node_groups = {
    argocd = {
      name           = "argocd"
      ami_type       = "AL2_ARM_64"
      instance_types = ["t4g.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 1
      desired_size = 1

      # Restrict this node group to the single worker AZ
      subnet_ids = [
        # Pick the subnet that resides in the requested worker AZ
        # Assumes first subnet corresponds to var.single_az (see vpc.tf ordering)
        module.vpc.public_subnets[0]
      ]

      labels = {
        role = "argocd"
      }
    }

    app = {
      name           = "app"
      ami_type       = "AL2_ARM_64"
      instance_types = ["t4g.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 1
      desired_size = 1

      # Restrict to same single AZ subnet as above
      subnet_ids = [
        module.vpc.public_subnets[0]
      ]

      labels = {
        role = "app"
      }
    }
  }
}


