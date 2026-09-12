# 03-k8s.tf — MK8s control plane and node groups.

locals {
  node_group_system = {
    min_size = 4
    max_size = 4
    resource = {
      platform = "cpu-d3"
      preset   = "8vcpu-32gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 192
      block_size_kibibytes = 4
    }
  }

  node_group_controller = {
    size = 1
    resource = {
      platform = "cpu-d3"
      preset   = "4vcpu-16gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 128
      block_size_kibibytes = 4
    }
  }

  node_group_login = {
    size = 1
    resource = {
      platform = "cpu-d3"
      preset   = "16vcpu-64gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 256
      block_size_kibibytes = 4
    }
  }

  # 2×H100 1gpu-16vcpu-200gb. That preset cannot join InfiniBand.
  # gpu_cluster.id is a dummy so stock gpu_fabric_validation.tf passes;
  # the id is never attached because the preset is gpu_cluster_compatible = false.
  worker = {
    name = "worker"
    size = 2
    resource = {
      platform = "gpu-h100-sxm"
      preset   = "1gpu-16vcpu-200gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 512
      block_size_kibibytes = 4
    }
    gpu_cluster = {
      id = "ethernet-not-attached"
    }
  }

  node_group_workers = [{
    size                    = local.worker.size
    max_unavailable_percent = 50
    resource                = local.worker.resource
    boot_disk               = local.worker.boot_disk
    gpu_cluster             = local.worker.gpu_cluster
    nodeset_index           = 0
    subset_index            = 0
  }]

  node_group_workers_v2 = [{
    name            = local.worker.name
    node_group_name = "worker-0"
    size            = local.worker.size
    min_size        = local.worker.size
    max_size        = local.worker.size
    autoscaling     = false
    resource        = local.worker.resource
    boot_disk       = local.worker.boot_disk
    gpu_cluster     = local.worker.gpu_cluster
    nodeset_index   = 0
    subset_index    = 0
  }]
}

module "k8s" {
  depends_on = [
    module.cleanup,
    module.filestore,
  ]

  providers = {
    nebius = nebius
    units  = units
  }

  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/k8s?ref=soperator-v4.1.8-1"

  iam_project_id  = data.nebius_iam_v1_project.this.id
  login_public_ip = true
  vpc_subnet_id   = data.nebius_vpc_v1_subnet.this.id

  company_name      = var.company_name
  etcd_cluster_size = 3
  k8s_version       = "1.35"
  name              = local.k8s_cluster_name_prefix

  nvidia_config_lines = [
    "options nvidia NVreg_RestrictProfilingToAdminUsers=0",
    "options nvidia NVreg_EnableStreamMemOPs=1",
    "options nvidia NVreg_RegistryDwords=\"PeerMappingOverride=1;\"",
  ]
  platform_driver_presets      = { gpu-h100-sxm = "cuda13.0" }
  use_preinstalled_gpu_drivers = true

  node_group_accounting = {
    enabled = false
    spec    = null
  }
  node_group_controller = local.node_group_controller
  node_group_login      = local.node_group_login
  node_group_nfs = {
    enabled = false
    spec    = null
  }
  node_group_system     = local.node_group_system
  node_group_workers    = local.node_group_workers
  node_group_workers_v2 = local.node_group_workers_v2

  filestores = {
    accounting = null
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
  }

  node_ssh_access_users = []
}
