variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "cypago-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_az" {
  description = "Single Availability Zone to host worker subnets"
  type        = string
  default     = "eu-west-1a"
}

variable "control_plane_secondary_az" {
  description = "A second AZ for control plane subnets (EKS requires >= 2 AZs); workers stay in single_az"
  type        = string
  default     = "eu-west-1b"
}


