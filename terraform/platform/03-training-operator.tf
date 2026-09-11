# Kubeflow Training Operator v1.9.3 — same install as the Nebius NCCL tutorial.

resource "terraform_data" "training_operator" {
  depends_on = [helm_release.gpu_operator, terraform_data.platform_k8s_wipe]

  triggers_replace = ["v1.9.3"]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = "kubectl apply --server-side --force-conflicts -k 'https://github.com/kubeflow/training-operator.git/manifests/overlays/standalone?ref=v1.9.3'"
  }
}
