# Flux CD — Soperator's installer, not our GitOps tool.
# The Slurm module publishes HelmReleases into flux-system. ArgoCD (01-argocd.tf)
# is what we use for demo-day apps. Do not remove Flux or Soperator will not reconcile.

module "fluxcd" {
  depends_on = [terraform_data.platform_k8s_wipe]

  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/fluxcd?ref=soperator-v4.1.8-1"

  k8s_cluster_context = local.infra.k8s_cluster_context
}
