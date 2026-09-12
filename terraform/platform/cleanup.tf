# Destroy-time Kubernetes cleanup.

# Created first (other platform resources depend_on it) so it is always in
# state. Destroy runs last: platform_k8s_wipe.sh strips Flux keep leftovers,
# CR finalizers, namespaces, and CRDs. 06-destroy_platform.sh runs the same
# script after destroy so an empty state still wipes the cluster.
resource "terraform_data" "platform_k8s_wipe" {
  input = {
    kubeconfig   = var.kubeconfig_path
    context      = local.infra.k8s_cluster_context
    flux_version = "v2.7.4"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG          = self.input.kubeconfig
      K8S_CLUSTER_CONTEXT = self.input.context
      FLUX_VERSION        = self.input.flux_version
    }
    command = "${path.module}/scripts/platform_k8s_wipe.sh"
  }
}

# Upstream hooks, before Helm uninstall: scale the Soperator controller down
# so it cannot recreate the login LoadBalancer, then delete Kruise webhooks
# that would block namespace deletion.
module "k8s_cleanup" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/k8s_cleanup?ref=soperator-v4.1.8-1"

  k8s_cluster_context = local.infra.k8s_cluster_context
  k8s_cluster_id      = local.infra.k8s_cluster_id

  depends_on = [module.slurm, terraform_data.platform_k8s_wipe]
}
