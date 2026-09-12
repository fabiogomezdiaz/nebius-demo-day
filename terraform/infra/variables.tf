# region Cloud

variable "region" {
  description = "Region of the project."
  type        = string
  nullable    = false
}
resource "terraform_data" "check_region" {
  lifecycle {
    precondition {
      condition     = contains(module.resources.regions, var.region)
      error_message = "Unknown region '${var.region}'. See https://docs.nebius.com/overview/regions"
    }
  }
}

variable "iam_project_id" {
  description = "ID of the IAM project."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.iam_project_id, "project-")
    error_message = "ID of the IAM project must start with `project-`."
  }
}
data "nebius_iam_v1_project" "this" {
  id = var.iam_project_id
}

variable "iam_tenant_id" {
  description = "ID of the IAM tenant."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.iam_tenant_id, "tenant-")
    error_message = "ID of the IAM tenant must start with `tenant-`."
  }
}

variable "vpc_subnet_id" {
  description = "ID of VPC subnet."
  type        = string

  validation {
    condition     = startswith(var.vpc_subnet_id, "vpcsubnet-")
    error_message = "The ID of the VPC subnet must start with `vpcsubnet-`."
  }
}
data "nebius_vpc_v1_subnet" "this" {
  id = var.vpc_subnet_id
}

variable "company_name" {
  description = "Name of the company. It is used for naming Slurm & K8s clusters."
  type        = string

  validation {
    condition = (
      length(var.company_name) >= 1 &&
      length(var.company_name) <= 32 &&
      length(regexall("^[a-z][a-z\\d\\-]*[a-z\\d]+$", var.company_name)) == 1
    )
    error_message = <<EOF
      The company name must:
      - be 1 to 32 characters long
      - start with a letter
      - end with a letter or digit
      - consist of letters, digits, or hyphens (-)
      - contain only lowercase letters
    EOF
  }
}

# endregion Cloud

# region Infrastructure

# Storage sizes are hardcoded in 02-filestore.tf. NFS is off.

# k8s 1.35, CUDA 13.0.2, driverfull image — hardcoded in 01-locals.tf / 04-k8s.tf.

# endregion Infrastructure

# region Slurm

# region Nodes

variable "slurm_nodeset_system" {
  description = "Configuration of System node set for system resources created by Soperator."
  type = object({
    min_size = number
    max_size = number
    resource = object({
      platform = string
      preset   = string
    })
    boot_disk = object({
      type                 = string
      size_gibibytes       = number
      block_size_kibibytes = number
    })
  })
  nullable = false
  default = {
    min_size = 3
    max_size = 9
    resource = {
      platform = "cpu-d3"
      preset   = "16vcpu-64gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 128
      block_size_kibibytes = 4
    }
  }
  validation {
    condition     = var.slurm_nodeset_system.boot_disk.size_gibibytes >= 128
    error_message = "Boot disks for system nodes must be at least 128 GiB."
  }
  validation {
    condition     = var.slurm_nodeset_system.min_size >= 3
    error_message = "Minimum size of the system node group must be at least 3."
  }
}

variable "slurm_nodeset_controller" {
  description = "Configuration of Slurm Controller node set. Only a single controller node is supported."
  type = object({
    size = number
    resource = object({
      platform = string
      preset   = string
    })
    boot_disk = object({
      type                 = string
      size_gibibytes       = number
      block_size_kibibytes = number
    })
  })
  nullable = false
  default = {
    size = 1
    resource = {
      platform = "cpu-d3"
      preset   = "16vcpu-64gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 128
      block_size_kibibytes = 4
    }
  }
  validation {
    condition     = var.slurm_nodeset_controller.boot_disk.size_gibibytes >= 128
    error_message = "Boot disks for controller nodes must be at least 128 GiB."
  }
  validation {
    condition     = var.slurm_nodeset_controller.size == 1
    error_message = "Size of the controller node group must be exactly 1."
  }
}

variable "slurm_nodeset_workers" {
  description = "Configuration of Slurm Worker node sets."
  type = list(object({
    name = string
    size = number
    autoscaling = optional(object({
      enabled  = optional(bool, true)
      min_size = optional(number)
    }), {})
    resource = object({
      platform = string
      preset   = string
    })
    boot_disk = object({
      type                 = string
      size_gibibytes       = number
      block_size_kibibytes = number
    })
    gpu_cluster = optional(object({
      id                = optional(string)
      infiniband_fabric = optional(string)
    }))
    preemptible = optional(object({}))
    reservation_policy = optional(object({
      policy          = optional(string)
      reservation_ids = optional(list(string))
    }))
    nvlink = optional(object({
      enabled = optional(bool, false)
      type    = optional(string, "GB300")
    }), {})
    placement_policy_nodes         = optional(list(string))
    features                       = optional(list(string))
    create_partition               = optional(bool)
    ephemeral_nodes                = optional(bool, false)
    initial_number_ephemeral_nodes = optional(number, 0)
    persistent_volume_claim_retention_policy = optional(object({
      when_deleted = string
      when_scaled  = string
    }))
    local_nvme = optional(object({
      enabled         = optional(bool, false)
      mount_path      = optional(string, "/mnt/local-nvme")
      filesystem_type = optional(string, "ext4")
    }), {})
    node_local_image_disk = object({
      enabled = bool
      spec = optional(object({
        size_gibibytes  = number
        filesystem_type = string
        disk_type       = string
      }))
    })
    node_local_jail_submounts = list(object({
      name            = string
      mount_path      = string
      size_gibibytes  = number
      disk_type       = string
      filesystem_type = string
    }))
  }))
  nullable = false
  default = [{
    name = "worker"
    size = 1
    resource = {
      platform = "cpu-d3"
      preset   = "16vcpu-64gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 512
      block_size_kibibytes = 4
    }
    node_local_image_disk = {
      enabled = false
    }
    node_local_jail_submounts = []
  }]

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.gpu_cluster == null || (
        length(try(trimspace(worker.gpu_cluster.id), "")) > 0 ||
        length(try(trimspace(worker.gpu_cluster.infiniband_fabric), "")) > 0
      )
    ])
    error_message = "slurm_nodeset_workers.gpu_cluster must set either id or infiniband_fabric."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.resource.platform == "gpu-gb300" ? (
        try(worker.size < local.gb300_nodes_per_nodegroup || worker.size % local.gb300_nodes_per_nodegroup == 0, false)
      ) : true
    ])
    error_message = "GB300 worker nodesets must have size divisible by ${local.gb300_nodes_per_nodegroup}."
  }

  validation {
    # NVLink is modeled only for GB300 here: GB300 must enable it and all other
    # platforms must leave it disabled.
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.resource.platform == "gpu-gb300" ? try(worker.nvlink.enabled == true, false) : !try(worker.nvlink.enabled == true, false)
    ])
    error_message = "NVLink must be enabled for gpu-gb300 worker nodesets and disabled for all other platforms."
  }

  validation {
    # The provider requires a type value for NVLink instance groups. This
    # installation path supports only GB300 groups.
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.resource.platform == "gpu-gb300" ? try(coalesce(worker.nvlink.type, "GB300") == "GB300", false) : true
    ])
    error_message = "GB300 worker nodesets must use nvlink.type = \"GB300\"."
  }

  validation {
    condition     = length(var.slurm_nodeset_workers) > 0
    error_message = "At least one worker nodeset must be provided."
  }

  validation {
    # Compare the set of generated worker NodeSet names with the full generated
    # name list; a shorter distinct list means two inputs collide after
    # expansion. Example collision: two non-GB workers named "worker" both
    # generate "worker".
    condition = length(distinct(flatten([
      for worker in var.slurm_nodeset_workers :
      worker.resource.platform == "gpu-gb300" ? [
        for rack in range(max(1, try(ceil(worker.size / 18), 0))) : format(
          "%s-rack%d",
          worker.name,
          rack,
        )
      ] : [worker.name]
      ]))) == length(flatten([
      for worker in var.slurm_nodeset_workers :
      worker.resource.platform == "gpu-gb300" ? [
        for rack in range(max(1, try(ceil(worker.size / 18), 0))) : format(
          "%s-rack%d",
          worker.name,
          rack,
        )
      ] : [worker.name]
    ]))
    error_message = "All effective worker nodeset names must be unique. GB300 worker nodesets are named <name>-rack<rack>; other worker nodesets use <name>."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      (worker.boot_disk.size_gibibytes >= 512)
    ])
    error_message = "Boot disks for worker nodes must be at least 512 GiB."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.autoscaling.min_size == null || worker.autoscaling.min_size <= worker.size
    ])
    error_message = "Worker nodeset autoscaling.min_size must be less than or equal to size."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      !try(worker.local_nvme.enabled, false) ||
      can(regex("^/[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$", try(worker.local_nvme.mount_path, "/mnt/local-nvme")))
    ])
    error_message = "When worker local NVMe is enabled, mount_path must be an absolute path containing only letters, digits, '/', '.', '_', and '-'."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      contains(["ext4", "xfs"], try(worker.local_nvme.filesystem_type, "ext4"))
    ])
    error_message = "When worker local NVMe filesystem_type is set, it must be `ext4` or `xfs`."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.node_local_image_disk.enabled ?
      worker.node_local_image_disk.spec != null : true
    ])
    error_message = "slurm_nodeset_workers.node_local_image_disk.spec must be provided if enabled."
  }
  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.node_local_image_disk.spec == null
      ? true
      : (contains(
        [
          module.resources.filesystem_types.ext4,
          module.resources.filesystem_types.xfs,
        ],
        worker.node_local_image_disk.spec.filesystem_type
      ))
    ])
    error_message = "slurm_nodeset_workers.node_local_image_disk.spec.filesystem_type must be one of `ext4` or `xfs`."
  }
  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.node_local_image_disk.spec == null
      ? true
      : (contains(
        [
          module.resources.disk_types.network_ssd_non_replicated,
          module.resources.disk_types.network_ssd_io_m3,
        ],
        worker.node_local_image_disk.spec.disk_type
      ))
    ])
    error_message = "Local image disk type must be one of `NETWORK_SSD_NON_REPLICATED` or `NETWORK_SSD_IO_M3`. See https://docs.nebius.com/compute/storage/types#disks-types"
  }
  validation {
    condition = alltrue(flatten([
      for worker in var.slurm_nodeset_workers : [
        for sm in worker.node_local_jail_submounts : (
          contains(
            [
              module.resources.disk_types.network_ssd,
              module.resources.disk_types.network_ssd_non_replicated,
              module.resources.disk_types.network_ssd_io_m3,
            ],
            sm.disk_type
          )
        )
      ]
    ]))
    error_message = "Disk type must be one of `NETWORK_SSD`, `NETWORK_SSD_NON_REPLICATED` or `NETWORK_SSD_IO_M3`. See https://docs.nebius.com/compute/storage/types#disks-types"
  }
  validation {
    condition = alltrue(flatten([
      for worker in var.slurm_nodeset_workers : [
        for sm in worker.node_local_jail_submounts : (
          contains(
            [
              module.resources.filesystem_types.ext4,
              module.resources.filesystem_types.xfs,
            ],
            sm.filesystem_type
          )
        )
      ]
    ]))
    error_message = "Filesystem type must be one of `ext4` or `xfs`."
  }

  validation {
    condition = alltrue([
      for worker in var.slurm_nodeset_workers :
      worker.persistent_volume_claim_retention_policy == null || (
        contains(["Retain", "Delete"], worker.persistent_volume_claim_retention_policy.when_deleted) &&
        contains(["Retain", "Delete"], worker.persistent_volume_claim_retention_policy.when_scaled)
      )
    ])
    error_message = "When worker persistent_volume_claim_retention_policy is set, when_deleted and when_scaled must be `Retain` or `Delete`."
  }
}

variable "slurm_nodeset_login" {
  description = "Configuration of Slurm Login node set."
  type = object({
    size               = number
    node_group_enabled = optional(bool, true)
    resource = object({
      platform = string
      preset   = string
    })
    boot_disk = object({
      type                 = string
      size_gibibytes       = number
      block_size_kibibytes = number
    })
  })
  nullable = false
  default = {
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
  validation {
    condition     = var.slurm_nodeset_login.boot_disk.size_gibibytes >= 256
    error_message = "Boot disks for login nodes must be at least 256 GiB."
  }
  validation {
    condition     = var.slurm_nodeset_login.size >= 1
    error_message = "Login replica count (slurm_nodeset_login.size) must be at least 1."
  }
}

resource "terraform_data" "check_slurm_nodeset" {
  for_each = merge({
    "system"     = var.slurm_nodeset_system
    "controller" = var.slurm_nodeset_controller
    "login"      = var.slurm_nodeset_login
    }, { for i, worker in var.slurm_nodeset_workers :
    "worker_${i}" => worker
    }
  )

  depends_on = [
    terraform_data.check_region,
  ]

  lifecycle {
    precondition {
      condition = (
        startswith(each.key, "worker_")
        ? (
          try(each.value.size >= 0 && floor(each.value.size) == each.value.size, false) &&
          (
            try(each.value.autoscaling.min_size, null) == null
            ? true
            : try(each.value.autoscaling.min_size >= 0 && floor(each.value.autoscaling.min_size) == each.value.autoscaling.min_size, false)
          )
        )
        : (
          try(each.value.size > 0 && floor(each.value.size) == each.value.size, false) ||
          try(each.value.min_size > 0 && floor(each.value.min_size) == each.value.min_size, false)
        )
      )
      error_message = "Node set ${each.key} must have whole-number size/min_size values. Worker node sets may use size = 0 and validate autoscaling.min_size when set; other node sets must have size or min_size greater than 0."
    }

    precondition {
      condition     = contains(module.resources.platforms, each.value.resource.platform)
      error_message = "Unsupported platform '${each.value.resource.platform}' in node set '${each.key}'."
    }

    precondition {
      condition     = contains(keys(module.resources.by_platform[each.value.resource.platform]), each.value.resource.preset)
      error_message = "Unsupported preset '${each.value.resource.preset}' for platform '${each.value.resource.platform}' in node set '${each.key}'."
    }

    precondition {
      condition     = contains(module.resources.platform_regions[each.value.resource.platform], var.region)
      error_message = "Unsupported platform '${each.value.resource.platform}' in region '${var.region}'. See https://docs.nebius.com/compute/virtual-machines/types"
    }

    # TODO: precondition for total node group count
  }
}

resource "terraform_data" "check_local_nvme" {
  lifecycle {
    precondition {
      condition = (
        !anytrue([
          for worker in var.slurm_nodeset_workers :
          try(worker.local_nvme.enabled, false)
        ]) ||
        alltrue([
          for worker in var.slurm_nodeset_workers :
          !try(worker.local_nvme.enabled, false) || (
            try(module.resources.local_nvme_supported_by_region_platform_preset[var.region][worker.resource.platform][worker.resource.preset], false)
          )
        ])
      )
      error_message = "Local NVMe is enabled, but one or more worker nodesets use unsupported region/platform/preset."
    }
  }
}

variable "slurm_login_ssh_root_public_keys" {
  description = "Authorized keys accepted for connecting to Slurm login nodes via SSH as 'root' user."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.slurm_login_ssh_root_public_keys) >= 1
    error_message = "At least one SSH public key must be provided."
  }

  validation {
    condition     = alltrue([for k in var.slurm_login_ssh_root_public_keys : length(k) > 0])
    error_message = "SSH public keys must not be empty strings."
  }
}
