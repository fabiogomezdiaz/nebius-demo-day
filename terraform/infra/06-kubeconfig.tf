# 06-kubeconfig.tf — Write a local kubeconfig for the platform and workloads stacks.
# Not stored in Vault. Gitignored. nebius exec plugin refreshes the IAM token.

locals {
  kubeconfig_path = abspath("${path.module}/../kubeconfig")
}

resource "terraform_data" "kubeconfig" {
  depends_on = [module.k8s]

  triggers_replace = [
    module.k8s.cluster_id,
    module.k8s.cluster_context,
  ]

  input = local.kubeconfig_path

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = join(" ", [
      "nebius", "mk8s", "cluster", "get-credentials",
      "--context-name", module.k8s.cluster_context,
      "--external",
      "--force",
      "--id", module.k8s.cluster_id,
    ])
  }
}

output "kubeconfig_path" {
  description = "Absolute path of the local kubeconfig used by platform and workloads Terraform."
  value       = local.kubeconfig_path
}
