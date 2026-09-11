# Upstream destroy hooks: login LoadBalancer Service and Kruise webhooks.
# Broader Flux/Soperator uninstall is terraform_data.platform_k8s_wipe
# (07-platform-wipe.tf) plus scripts/platform_k8s_wipe.sh.

module "k8s_cleanup" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/k8s_cleanup?ref=soperator-v4.1.8-1"

  k8s_cluster_context = local.infra.k8s_cluster_context
  k8s_cluster_id      = local.infra.k8s_cluster_id

  depends_on = [module.slurm, terraform_data.platform_k8s_wipe]
}
