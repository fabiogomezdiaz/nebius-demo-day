# 04-k8s.tf — MK8s control plane and node groups.

module "k8s" {
  # --- Dependencies ---
  depends_on = [
    module.filestore,
    module.cleanup,
    terraform_data.check_slurm_nodeset,
  ]

  providers = {
    nebius = nebius
    units  = units
  }

  # --- Source ---
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/k8s?ref=soperator-v4.1.8-1"

  # --- Project & Networking ---
  iam_project_id  = data.nebius_iam_v1_project.this.id
  vpc_subnet_id   = data.nebius_vpc_v1_subnet.this.id
  login_public_ip = true

  # --- General Cluster Settings ---
  k8s_version       = "1.35"
  name              = local.k8s_cluster_name_prefix
  company_name      = var.company_name
  etcd_cluster_size = 3

  # --- GPU/Platform Settings ---
  platform_driver_presets      = { gpu-h100-sxm = "cuda13.0" }
  use_preinstalled_gpu_drivers = true
  nvidia_config_lines = [
    "options nvidia NVreg_RestrictProfilingToAdminUsers=0",
    "options nvidia NVreg_EnableStreamMemOPs=1",
    "options nvidia NVreg_RegistryDwords=\"PeerMappingOverride=1;\"",
  ]

  # --- Node Groups ---
  node_group_system     = var.slurm_nodeset_system
  node_group_controller = var.slurm_nodeset_controller
  node_group_workers    = local.node_group_workers
  node_group_workers_v2 = local.node_group_workers_v2
  node_group_login      = var.slurm_nodeset_login

  node_group_accounting = {
    enabled = false
    spec    = null
  }
  node_group_nfs = {
    enabled = false
    spec    = null
  }

  # --- Filestores ---
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

  # --- Access Control ---
  node_ssh_access_users = []
}
