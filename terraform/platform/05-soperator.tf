# Soperator / Slurm operator + SlurmCluster CR (Helm → Flux HelmReleases).
# Public o11y (Nebius-hosted telemetry) and Slurm backups are off for this lab;
# those modules are not instantiated.
# The module wait for soperator-activechecks is unconditional (240m). See
# 08-soperator-flux-overlay.tf — that patches Flux values so the install hook
# does not block on Slurm jobs that never get a status write here.

module "slurm" {
  depends_on = [module.fluxcd, terraform_data.platform_k8s_wipe]

  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/slurm?ref=soperator-v4.1.8-1"

  # --- Basic identities & cluster ---
  cluster_name        = local.s.cluster_name
  flux_namespace      = local.s.flux_namespace
  iam_project_id      = local.s.iam_project_id
  iam_tenant_id       = local.s.iam_tenant_id
  k8s_cluster_context = local.infra.k8s_cluster_context
  k8s_cluster_id      = local.infra.k8s_cluster_id
  name                = local.s.name
  region              = local.s.region

  # --- Operator versions & maintenance ---
  maintenance                    = local.s.maintenance
  maintenance_ignore_node_groups = local.s.maintenance_ignore_node_groups
  operator_stable                = local.s.operator_stable
  operator_version               = local.s.operator_version

  # --- Worker/nodegroup/node configuration ---
  cuda_version                   = local.s.cuda_version
  node_count                     = local.s.node_count
  shared_memory_size_gibibytes   = local.s.shared_memory_size_gibibytes
  topology                       = local.s.topology
  use_preinstalled_gpu_drivers   = local.s.use_preinstalled_gpu_drivers
  worker_nodesets                = local.s.worker_nodesets

  # --- Storage & filesystems ---
  controller_state_on_filestore  = local.s.controller_state_on_filestore
  filestores                     = local.s.filestores
  nfs                            = local.s.nfs
  nfs_in_k8s                     = local.s.nfs_in_k8s
  nfs_node_group_enabled         = local.s.nfs_node_group_enabled

  # --- Security & access ---
  login_allocation_id              = local.s.login_allocation_id
  login_on_worker_nodes            = local.s.login_on_worker_nodes
  login_public_ip                  = local.s.login_public_ip
  login_ssh_root_public_keys       = local.s.login_ssh_root_public_keys
  login_sshd_config_map_ref_name   = local.s.login_sshd_config_map_ref_name
  ssd_conf_secret_ref_name         = local.s.sssd_conf_secret_ref_name
  ssd_ldap_ca_config_map_ref_name  = local.s.sssd_ldap_ca_config_map_ref_name
  ssd_enabled                      = local.s.sssd_enabled
  tailscale_enabled                = local.s.tailscale_enabled
  use_default_apparmor_profile     = local.s.use_default_apparmor_profile
  worker_sshd_config_map_ref_name  = local.s.worker_sshd_config_map_ref_name

  # --- Partitioning, health checks, & resources ---
  resources                   = local.s.resources
  slurm_accounting_config     = {}
  slurm_health_check_config   = local.s.slurm_health_check_config
  slurm_nodesets_partitions   = local.s.slurm_nodesets_partitions
  slurm_partition_config_type = local.s.slurm_partition_config_type
  slurm_partition_raw_config  = local.s.slurm_partition_raw_config
  slurmdbd_config             = {}

  # --- Monitoring, reporting, and integrations ---
  accounting_enabled     = false
  active_checks_scope    = local.s.active_checks_scope
  exporter_enabled       = local.s.exporter_enabled
  public_o11y_enabled    = local.s.public_o11y_enabled
  rest_enabled           = local.s.rest_enabled
  soperator_notifier     = local.s.soperator_notifier
  telemetry_enabled      = local.s.telemetry_enabled

  # --- Backup configuration ---
  backups_enabled = local.s.backups_enabled
  backups_config = {
    password       = "unused"
    prune_schedule = "@daily-random"
    retention      = { keepDaily = 7 }
    schedule       = "@daily-random"
    secret_name    = null
    storage = {
      bucket    = null
      bucket_id = null
      endpoint  = null
    }
  }

  providers = {
    helm = helm
  }
}
