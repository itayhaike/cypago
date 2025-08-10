terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Pin to AWS provider v5 to avoid incompatible removals in v6 (e.g., elastic_inference_accelerator)
      version = ">= 5.0, < 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}


