# 02-filestore.tf — Jail, controller spool, and /mnt/data filesystems.

module "filestore" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/filestore?ref=soperator-v4.1.8-1"

  depends_on = [
    terraform_data.check_variables,
  ]

  iam_project_id = data.nebius_iam_v1_project.this.id

  k8s_cluster_name = local.k8s_cluster_name

  controller_spool = {
    spec = var.filestore_controller_spool.spec != null ? {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = var.filestore_controller_spool.spec.size_gibibytes
      block_size_kibibytes = var.filestore_controller_spool.spec.block_size_kibibytes
      forbid_deletion      = var.filestore_controller_spool.spec.forbid_deletion
    } : null
    existing = var.filestore_controller_spool.existing != null ? {
      id = var.filestore_controller_spool.existing.id
    } : null
  }

  accounting = var.accounting_enabled && var.filestore_accounting != null ? {
    spec = try(var.filestore_accounting.spec, null) != null ? {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = var.filestore_accounting.spec.size_gibibytes
      block_size_kibibytes = var.filestore_accounting.spec.block_size_kibibytes
      forbid_deletion      = var.filestore_accounting.spec.forbid_deletion
    } : null
    existing = try(var.filestore_accounting.existing, null) != null ? {
      id = var.filestore_accounting.existing.id
    } : null
  } : null

  jail = {
    spec = var.filestore_jail.spec != null ? {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = var.filestore_jail.spec.size_gibibytes
      block_size_kibibytes = var.filestore_jail.spec.block_size_kibibytes
      forbid_deletion      = var.filestore_jail.spec.forbid_deletion
    } : null
    existing = var.filestore_jail.existing != null ? {
      id = var.filestore_jail.existing.id
    } : null
  }

  jail_submounts = [for submount in var.filestore_jail_submounts : {
    name = submount.name
    spec = submount.spec != null ? {
      disk_type            = "NETWORK_SSD"
      size_gibibytes       = submount.spec.size_gibibytes
      block_size_kibibytes = submount.spec.block_size_kibibytes
      forbid_deletion      = submount.spec.forbid_deletion
    } : null
    existing = submount.existing != null ? {
      id = submount.existing.id
    } : null
  }]

  providers = {
    nebius = nebius
    units  = units
  }
}
