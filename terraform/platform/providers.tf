# Kubernetes and Helm talk to MK8s via a local kubeconfig written by the
# infra stack (terraform/kubeconfig). Not stored in Vault.

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}
