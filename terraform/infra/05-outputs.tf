# 05-outputs.tf — Values platform needs to install Soperator/Flux.

locals {
  soperator = {
    region                       = var.region
    iam_tenant_id                = var.iam_tenant_id
    iam_project_id               = var.iam_project_id
    cluster_name                 = var.company_name
    name                         = local.slurm_cluster_name
    use_preinstalled_gpu_drivers = true
    cuda_version                 = "13.0.2"
    node_count = {
      controller = local.node_group_controller.size
      worker     = [local.worker.size]
      login      = local.node_group_login.size
    }
    resources = {
      system = {
        cpu_cores        = local.resources.system.cpu_cores
        memory_gibibytes = local.resources.system.memory_gibibytes
        ephemeral_storage_gibibytes = floor(
          local.node_group_system.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
      }
      controller = {
        cpu_cores        = local.resources.controller.cpu_cores
        memory_gibibytes = floor(local.resources.controller.memory_gibibytes)
        ephemeral_storage_gibibytes = floor(
          local.node_group_controller.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
      }
      worker = [{
        cpu_cores        = local.resources.worker.cpu_cores
        memory_gibibytes = floor(local.resources.worker.memory_gibibytes)
        ephemeral_storage_gibibytes = floor(
          local.worker.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
        gpus = local.resources.worker.gpus
      }]
      login = {
        cpu_cores        = local.resources.login.cpu_cores
        memory_gibibytes = floor(local.resources.login.memory_gibibytes)
        ephemeral_storage_gibibytes = floor(
          local.node_group_login.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
      }
      accounting = null
      nfs        = null
    }
    filestores = {
      controller_spool = {
        size_gibibytes = module.filestore.controller_spool.size_gibibytes
        device         = module.filestore.controller_spool.mount_tag
      }
      jail = {
        size_gibibytes = module.filestore.jail.size_gibibytes
        device         = module.filestore.jail.mount_tag
      }
      jail_submounts = [for submount in local.filestore_jail_submounts : {
        name           = submount.name
        size_gibibytes = module.filestore.jail_submounts[submount.name].size_gibibytes
        device         = module.filestore.jail_submounts[submount.name].mount_tag
        mount_path     = submount.mount_path
      }]
      accounting = null
    }
    login_on_worker_nodes = false
    worker_nodesets = [{
      name            = local.worker.name
      replicas        = local.worker.size
      max_unavailable = "20%"
      features = [
        provider::string-functions::snake_case(local.worker.resource.platform),
        provider::string-functions::snake_case(local.worker.boot_disk.type),
      ]
      cpu_topology = module.resources.cpu_topology_by_platform[local.worker.resource.platform][local.worker.resource.preset]
      gres_name    = lookup(module.resources.gres_name_by_platform, local.worker.resource.platform, null)
      # Stock gres_config_by_platform is the 8-GPU SKU (Cores=0-31 / 32-63).
      # 1gpu-16vcpu-200gb has 16 CPUs and /dev/nvidia0; slurmctld fatals otherwise.
      gres_config = [
        format(
          "AutoDetect=off Name=gpu Type=%s File=/dev/nvidia0 Cores=0-%d Links=-1 Flags=nvidia_gpu_env",
          lookup(module.resources.gres_name_by_platform, local.worker.resource.platform, "gpu"),
          module.resources.cpu_topology_by_platform[local.worker.resource.platform][local.worker.resource.preset].cpus - 1,
        )
      ]
      create_partition = false
      ephemeral_nodes  = false
      persistent_volume_claim_retention_policy = {
        when_deleted = "Delete"
        when_scaled  = "Delete"
      }
      initial_number_ephemeral_nodes = 1
      local_nvme = {
        enabled         = false
        mount_path      = "/mnt/local-nvme"
        filesystem_type = "ext4"
      }
      node_local_jail_submounts = []
      node_local_image_storage = {
        enabled = false
        spec    = null
      }
    }]
    topology = {
      plugin     = "topology/tree"
      block_size = null
    }
    login_allocation_id        = module.k8s.static_ip_allocation_id
    login_public_ip            = true
    login_ssh_root_public_keys = var.slurm_login_ssh_root_public_keys
    flux_namespace             = local.flux_namespace
  }
}

output "k8s_cluster_id" {
  description = "MK8s cluster ID."
  value       = module.k8s.cluster_id
}

output "k8s_cluster_context" {
  description = "kubectl context name written by the k8s module."
  value       = module.k8s.cluster_context
}

output "slurm_cluster_name" {
  description = "SlurmCluster namespace/name (soperator)."
  value       = local.slurm_cluster_name
}

output "soperator" {
  description = "Inputs for the Soperator/Slurm Helm module in terraform/platform."
  value       = local.soperator
}
