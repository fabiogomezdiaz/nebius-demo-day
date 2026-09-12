# 04-k8s.tf — MK8s control plane and node groups.

resource "nebius_compute_v1_nvl_instance_group" "worker" {
  for_each = {
    for key, worker in local.node_group_workers_v2_by_key :
    key => worker
    if try(worker.nvlink.enabled == true, false)
  }

  parent_id = var.iam_project_id
  size      = local.nvl_instance_group_size
  name      = "${local.k8s_cluster_name}-${each.value.node_group_name}"
  type      = each.value.nvlink.type
}

module "k8s" {
  depends_on = [
    module.filestore,
    module.cleanup,
    terraform_data.check_slurm_nodeset,
  ]

  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/k8s?ref=soperator-v4.1.8-1"

  iam_project_id  = data.nebius_iam_v1_project.this.id
  vpc_subnet_id   = data.nebius_vpc_v1_subnet.this.id
  login_public_ip = var.slurm_login_public_ip

  k8s_version                  = var.k8s_version
  name                         = local.k8s_cluster_name
  company_name                 = var.company_name
  platform_driver_presets      = var.platform_driver_presets
  use_preinstalled_gpu_drivers = var.use_preinstalled_gpu_drivers

  etcd_cluster_size = var.etcd_cluster_size

  node_group_system     = var.slurm_nodeset_system
  node_group_controller = var.slurm_nodeset_controller
  node_group_workers    = local.node_group_workers
  node_group_workers_v2 = [
    for worker in local.node_group_workers_v2 : merge(worker, {
      nvl_instance_group_id = try(nebius_compute_v1_nvl_instance_group.worker[worker.node_group_name].id, "")
    })
  ]
  node_group_login = local.login_node_group
  node_group_accounting = {
    enabled = false
    spec    = null
  }
  node_group_nfs = {
    enabled = false
    spec    = null
  }

  filestores = {
    controller_spool = {
      id        = module.filestore.controller_spool.id
      mount_tag = module.filestore.controller_spool.mount_tag
    }
    jail = {
      id        = module.filestore.jail.id
      mount_tag = module.filestore.jail.mount_tag
    }
    jail_submounts = [for key, submount in module.filestore.jail_submounts : {
      id        = submount.id
      mount_tag = submount.mount_tag
    }]
    accounting = null
  }

  node_ssh_access_users = var.k8s_cluster_node_ssh_access_users
  nvidia_config_lines   = var.nvidia_config_lines

  providers = {
    nebius = nebius
    units  = units
  }
}
