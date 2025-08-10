// VPC with public subnets. Control plane needs subnets in at least two AZs,
// but worker node groups will be constrained to a single AZ as requested.

locals {
  // Respect requested single AZ for workers, but EKS control plane needs >= 2 AZs.
  worker_az = var.single_az

  // Secondary AZ is provided via variable to avoid needing ec2:DescribeAvailabilityZones permission
  other_az = var.control_plane_secondary_az

  // Ensure first subnet is created in the requested single AZ, second in another AZ for control plane.
  control_plane_azs = [local.worker_az, local.other_az]

  // Simple CIDR segmentation for two public subnets
  public_cidrs = [
    cidrsubnet(var.vpc_cidr, 4, 0),
    cidrsubnet(var.vpc_cidr, 4, 1),
  ]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs            = local.control_plane_azs
  public_subnets = local.public_cidrs

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  enable_nat_gateway = false
  single_nat_gateway = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  vpc_tags = {
    Name = "${var.cluster_name}-vpc"
  }
}


