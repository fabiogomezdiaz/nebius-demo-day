# The slurm module always waits up to 240 minutes for
# flux-system-soperator-fluxcd-soperator-activechecks. That wait is not
# configurable. Flux optionally merges ConfigMap soperator-fluxcd-values;
# the module creates it empty and ignore_changes it. Patch that CM in
# parallel with module.slurm (do not depends_on the module — that wait
# is inside it) so child HelmReleases skip Slurm jobs that hang bootstrap.
resource "terraform_data" "soperator_flux_overlay" {
  depends_on = [module.fluxcd, terraform_data.platform_k8s_wipe]

  input = filesha256("${path.module}/scripts/soperator_fluxcd_values_overlay.yaml")

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG          = var.kubeconfig_path
      K8S_CLUSTER_CONTEXT = local.infra.k8s_cluster_context
    }
    command = "${path.module}/scripts/apply_soperator_flux_overlay.sh"
  }
}
