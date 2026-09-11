# ArgoCD — GitOps control plane for demo-day apps.
# Soperator still uses Flux (04-fluxcd.tf). Do not replace Flux with ArgoCD.

resource "helm_release" "argocd" {
  depends_on = [terraform_data.platform_k8s_wipe]

  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.8.28"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        extraArgs = ["--insecure"]
      }
    })
  ]
}

output "argocd_namespace" {
  value = helm_release.argocd.namespace
}
