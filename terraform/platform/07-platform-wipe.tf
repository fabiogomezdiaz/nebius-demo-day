# Marker created first so it is always in state, even if Soperator apply hangs.
# Other platform resources depend on it, so terraform destroy uninstalls Helm
# first and then this script removes Flux keep leftovers, CR finalizers, and
# namespaces. ./scripts/06-destroy_platform.sh also runs the same script after
# destroy so an empty state still wipes the cluster.

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
