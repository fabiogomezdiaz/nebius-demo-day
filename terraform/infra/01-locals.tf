# 01-locals.tf — Naming, nodeset expansion, and variable checks.

module "resources" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/available_resources?ref=soperator-v4.1.8-1"
}

locals {
  resources = {
    system     = module.resources.by_platform[var.slurm_nodeset_system.resource.platform][var.slurm_nodeset_system.resource.preset]
    controller = module.resources.by_platform[var.slurm_nodeset_controller.resource.platform][var.slurm_nodeset_controller.resource.preset]
    workers    = [for worker in local.slurm_nodeset_workers : module.resources.by_platform[worker.resource.platform][worker.resource.preset]]
    login      = module.resources.by_platform[var.slurm_nodeset_login.resource.platform][var.slurm_nodeset_login.resource.preset]
    accounting = var.slurm_nodeset_accounting != null ? module.resources.by_platform[var.slurm_nodeset_accounting.resource.platform][var.slurm_nodeset_accounting.resource.preset] : null
    nfs        = var.slurm_nodeset_nfs != null ? module.resources.by_platform[var.slurm_nodeset_nfs.resource.platform][var.slurm_nodeset_nfs.resource.preset] : null
  }

  # keep in sync with helm chart
  # https://github.com/nebius/soperator/blob/main/helm/storageclasses/templates/storageclasses.yaml#L4
  storage_class_prefix = "compute-csi"

  slurm_cluster_name = "soperator"
  flux_namespace     = "flux-system"
  k8s_cluster_name   = format("soperator-%s", var.company_name)

  gb300_platform              = "gpu-gb300"
  gb300_nodes_per_nodegroup   = 18
  nvl_instance_group_size     = 18
  default_nodes_per_nodegroup = 100
  gb300_enabled               = anytrue([for nodeset in var.slurm_nodeset_workers : nodeset.resource.platform == local.gb300_platform])

  # GB300 keeps slurm_nodeset_login.size non-zero in tfvars so Soperator still
  # creates login pods, while Terraform skips the separate unused CPU login node
  # group. Non-GB300 platforms keep the configured login node group behavior.
  login_node_group = merge(var.slurm_nodeset_login, {
    node_group_enabled = local.gb300_enabled ? false : var.slurm_nodeset_login.node_group_enabled
  })

  # Normalize user-facing worker nodesets into the internal nodeset list used
  # by both mk8s node groups and Slurm NodeSets. GB300 is rack-addressed, so one
  # input nodeset expands into 18-node rack chunks named <name>-rack<rack>.
  # Example: { name = "worker", platform = "gpu-gb300", size = 36 } becomes
  # [{ name = "worker-rack0", size = 18 }, { name = "worker-rack1", size = 18 }].
  # Non-production partial racks keep their requested size, for example size = 10
  # becomes [{ name = "worker-rack0", size = 10 }]. Size = 0 keeps a
  # zero-replica rack nodeset so Terraform can downscale the generated node
  # groups while the Slurm NodeSet remains addressable.
  slurm_nodeset_workers = flatten([
    for nodeset in var.slurm_nodeset_workers :
    nodeset.resource.platform == local.gb300_platform ? [
      for rack in range(max(1, ceil(nodeset.size / local.gb300_nodes_per_nodegroup))) : merge(nodeset, {
        name = format(
          "%s-rack%d",
          nodeset.name,
          rack,
        )
        size                = min(local.gb300_nodes_per_nodegroup, nodeset.size - rack * local.gb300_nodes_per_nodegroup)
        nodes_per_nodegroup = local.gb300_nodes_per_nodegroup
      })
      ] : [merge(nodeset, {
        nodes_per_nodegroup = local.default_nodes_per_nodegroup
    })]
  ])

  # Legacy node_group_workers for old-style deployments (without nodesets).
  # Splits each normalized nodeset into mk8s node group chunks.
  # Example: size = 250 and nodes_per_nodegroup = 100 produces sizes [100, 100, 50].
  node_group_workers = flatten([for i, nodeset in local.slurm_nodeset_workers : [
    for subset in range(ceil(nodeset.size / nodeset.nodes_per_nodegroup)) : {
      size                    = min(nodeset.nodes_per_nodegroup, nodeset.size - subset * nodeset.nodes_per_nodegroup)
      max_unavailable_percent = 50
      max_surge_percent       = null
      drain_timeout           = null
      resource                = nodeset.resource
      boot_disk               = nodeset.boot_disk
      gpu_cluster             = nodeset.gpu_cluster
      nodeset_index           = i
      subset_index            = subset
      preemptible             = nodeset.preemptible
    }
  ]])

  # V2 node_group_workers for new-style deployments (with nodesets)
  # Non-GB300 workers keep autoscaling and split into nodes_per_nodegroup chunks.
  # GB300 workers are fixed generated rack-sized groups because NVLink instance
  # groups are rack-scoped. Example: non-GB300 size = 128 becomes worker-0 size
  # 100 and worker-1 size 28; GB300 worker-rack0 stays size/min/max
  # equal to its normalized rack size with autoscaling off.
  node_group_workers_v2 = flatten([for i, nodeset in local.slurm_nodeset_workers : [
    for subset in range(ceil(nodeset.size / nodeset.nodes_per_nodegroup)) : {
      name            = nodeset.name
      node_group_name = nodeset.resource.platform == local.gb300_platform ? nodeset.name : join("-", [nodeset.name, subset])
      size            = nodeset.resource.platform == local.gb300_platform ? nodeset.size : min(nodeset.nodes_per_nodegroup, nodeset.size - subset * nodeset.nodes_per_nodegroup)
      min_size = nodeset.resource.platform == local.gb300_platform ? nodeset.size : (
        nodeset.autoscaling.enabled && nodeset.autoscaling.min_size != null
        # Fill autoscaling min_size left to right. Example: min_size = 120 over
        # 100-node chunks gives per-node-group min sizes [100, 20, 0].
        ? min(nodeset.nodes_per_nodegroup, max(0, nodeset.autoscaling.min_size - subset * nodeset.nodes_per_nodegroup))
        : min(nodeset.nodes_per_nodegroup, nodeset.size - subset * nodeset.nodes_per_nodegroup) # min=max
      )
      max_size               = nodeset.resource.platform == local.gb300_platform ? nodeset.size : max(1, min(nodeset.nodes_per_nodegroup, nodeset.size - subset * nodeset.nodes_per_nodegroup))
      autoscaling            = nodeset.resource.platform == local.gb300_platform ? false : nodeset.autoscaling.enabled
      resource               = nodeset.resource
      boot_disk              = nodeset.boot_disk
      gpu_cluster            = nodeset.gpu_cluster
      nodeset_index          = i
      subset_index           = subset
      preemptible            = nodeset.preemptible
      reservation_policy     = nodeset.reservation_policy
      nvlink                 = nodeset.nvlink
      placement_policy_nodes = nodeset.placement_policy_nodes
      local_nvme = {
        enabled         = try(nodeset.local_nvme.enabled, false)
        mount_path      = try(nodeset.local_nvme.mount_path, "/mnt/local-nvme")
        filesystem_type = try(nodeset.local_nvme.filesystem_type, "ext4")
      }
    }
  ]])

  # Key by final mk8s node group name so NVLink resources can be created and
  # looked up with the same identifier.
  node_group_workers_v2_by_key = {
    for worker in local.node_group_workers_v2 :
    worker.node_group_name => worker
  }
}

resource "terraform_data" "check_variables" {
  depends_on = [
    terraform_data.check_slurm_nodeset,
    terraform_data.check_slurm_nodeset_accounting,
    terraform_data.check_local_nvme,
  ]
}
