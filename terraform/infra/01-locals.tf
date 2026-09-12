# 01-locals.tf — Naming and resource-catalog lookups.

module "resources" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/available_resources?ref=soperator-v4.1.8-1"
}

locals {
  resources = {
    system     = module.resources.by_platform[local.node_group_system.resource.platform][local.node_group_system.resource.preset]
    controller = module.resources.by_platform[local.node_group_controller.resource.platform][local.node_group_controller.resource.preset]
    worker     = module.resources.by_platform[local.worker.resource.platform][local.worker.resource.preset]
    login      = module.resources.by_platform[local.node_group_login.resource.platform][local.node_group_login.resource.preset]
  }

  filestore_jail_submounts = [{
    name                 = "data"
    mount_path           = "/mnt/data"
    size_gibibytes       = 512
    block_size_kibibytes = 4
    forbid_deletion      = false
  }]

  slurm_cluster_name      = "soperator"
  flux_namespace          = "flux-system"
  k8s_cluster_name_prefix = format("soperator-%s", var.company_name)
}
