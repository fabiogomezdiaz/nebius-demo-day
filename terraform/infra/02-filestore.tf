# 02-filestore.tf — Jail, controller spool, and /mnt/data filesystems.
# Sizes live here. Task 1 always creates new filesystems.

module "filestore" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/filestore?ref=soperator-v4.1.8-1"

  depends_on = [
    terraform_data.check_variables,
  ]

  iam_project_id = data.nebius_iam_v1_project.this.id

  k8s_cluster_name = local.k8s_cluster_name

  controller_spool = {
    spec = {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = 128
      block_size_kibibytes = 4
      forbid_deletion      = false
    }
    existing = null
  }

  # Task 1 does not run slurmdbd. No accounting filesystem.
  accounting = null

  jail = {
    spec = {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = 256
      block_size_kibibytes = 4
      forbid_deletion      = false
    }
    existing = null
  }

  jail_submounts = [for submount in local.filestore_jail_submounts : {
    name = submount.name
    spec = {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = submount.size_gibibytes
      block_size_kibibytes = submount.block_size_kibibytes
      forbid_deletion      = submount.forbid_deletion
    }
    existing = null
  }]

  providers = {
    nebius = nebius
    units  = units
  }
}
