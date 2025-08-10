# ArgoCD deployment via official Helm chart, constrained to run only on nodes labeled role=argocd

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  # Ensure providers can authenticate: cluster creator has admin via module setting
  depends_on = [module.eks]
}

locals {
  argocd_values = yamlencode({
    installCRDs = true
    controller = {
      nodeSelector = { role = "argocd" }
    }
    repoServer = {
      nodeSelector = { role = "argocd" }
    }
    server = {
      nodeSelector = { role = "argocd" }
    }
    applicationSet = {
      nodeSelector = { role = "argocd" }
    }
    dex = {
      nodeSelector = { role = "argocd" }
    }
    redis = {
      nodeSelector = { role = "argocd" }
    }
    notifications = {
      nodeSelector = { role = "argocd" }
    }
  })
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "6.11.0"

  values = [local.argocd_values]

  depends_on = [kubernetes_namespace.argocd]
}


