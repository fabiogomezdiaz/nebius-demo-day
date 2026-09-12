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
      controller = var.slurm_nodeset_controller.size
      worker     = [for workers in local.slurm_nodeset_workers : workers.size]
      login      = var.slurm_nodeset_login.size
    }
    resources = {
      system = {
        cpu_cores        = local.resources.system.cpu_cores
        memory_gibibytes = local.resources.system.memory_gibibytes
        ephemeral_storage_gibibytes = floor(
          var.slurm_nodeset_system.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
      }
      controller = {
        cpu_cores        = local.resources.controller.cpu_cores
        memory_gibibytes = floor(local.resources.controller.memory_gibibytes)
        ephemeral_storage_gibibytes = floor(
          var.slurm_nodeset_controller.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
          -module.resources.k8s_ephemeral_storage_reserve.gibibytes
        )
      }
      worker = [for i, worker in local.slurm_nodeset_workers :
        {
          cpu_cores        = local.resources.workers[i].cpu_cores
          memory_gibibytes = floor(local.resources.workers[i].memory_gibibytes)
          ephemeral_storage_gibibytes = floor(
            worker.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
            -module.resources.k8s_ephemeral_storage_reserve.gibibytes
          )
          gpus = local.resources.workers[i].gpus
        }
      ]
      login = {
        cpu_cores        = local.resources.login.cpu_cores
        memory_gibibytes = floor(local.resources.login.memory_gibibytes)
        ephemeral_storage_gibibytes = floor(
          var.slurm_nodeset_login.boot_disk.size_gibibytes * module.resources.k8s_ephemeral_storage_coefficient
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
    login_on_worker_nodes = local.gb300_enabled
    worker_nodesets = [for nodeset in local.slurm_nodeset_workers : {
      name            = nodeset.name
      replicas        = nodeset.size
      max_unavailable = "20%"
      features = concat(
        [
          provider::string-functions::snake_case(nodeset.resource.platform),
          provider::string-functions::snake_case(nodeset.boot_disk.type),
        ],
        nodeset.features != null ? nodeset.features : []
      )
      cpu_topology = module.resources.cpu_topology_by_platform[nodeset.resource.platform][nodeset.resource.preset]
      gres_name    = lookup(module.resources.gres_name_by_platform, nodeset.resource.platform, null)
      # Stock gres_config_by_platform is the 8-GPU SKU (Cores=0-31 / 32-63).
      # 1gpu-16vcpu-200gb has 16 CPUs and /dev/nvidia0; slurmctld fatals otherwise.
      gres_config = (
        module.resources.by_platform[nodeset.resource.platform][nodeset.resource.preset].gpus == 1
        ? [
          format(
            "AutoDetect=off Name=gpu Type=%s File=/dev/nvidia0 Cores=0-%d Links=-1 Flags=nvidia_gpu_env",
            lookup(module.resources.gres_name_by_platform, nodeset.resource.platform, "gpu"),
            module.resources.cpu_topology_by_platform[nodeset.resource.platform][nodeset.resource.preset].cpus - 1,
          )
        ]
        : lookup(module.resources.gres_config_by_platform, nodeset.resource.platform, null)
      )
      create_partition                         = nodeset.create_partition != null ? nodeset.create_partition : false
      ephemeral_nodes                          = nodeset.ephemeral_nodes
      persistent_volume_claim_retention_policy = nodeset.persistent_volume_claim_retention_policy
      initial_number_ephemeral_nodes           = nodeset.initial_number_ephemeral_nodes
      local_nvme = {
        enabled         = try(nodeset.local_nvme.enabled, false)
        mount_path      = try(nodeset.local_nvme.mount_path, "/mnt/local-nvme")
        filesystem_type = try(nodeset.local_nvme.filesystem_type, "ext4")
      }
      node_local_jail_submounts = [for sm in nodeset.node_local_jail_submounts : {
        name               = sm.name
        mount_path         = sm.mount_path
        size_gibibytes     = sm.size_gibibytes
        disk_type          = sm.disk_type
        filesystem_type    = sm.filesystem_type
        storage_class_name = replace("${local.storage_class_prefix}-${lower(sm.disk_type)}-${lower(sm.filesystem_type)}", "_", "-")
      }]
      node_local_image_storage = {
        enabled = nodeset.node_local_image_disk.enabled
        spec = nodeset.node_local_image_disk.enabled ? {
          size_gibibytes     = nodeset.node_local_image_disk.spec.size_gibibytes
          filesystem_type    = nodeset.node_local_image_disk.spec.filesystem_type
          storage_class_name = replace("${local.storage_class_prefix}-${lower(nodeset.node_local_image_disk.spec.disk_type)}-${lower(nodeset.node_local_image_disk.spec.filesystem_type)}", "_", "-")
        } : null
      }
    }]
    topology = {
      plugin     = local.gb300_enabled ? "topology/block" : "topology/tree"
      block_size = local.gb300_enabled ? local.gb300_nodes_per_nodegroup : null
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
