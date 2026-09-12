# Soperator / Slurm operator + SlurmCluster CR (Helm → Flux HelmReleases).
# Public o11y (Nebius-hosted telemetry) and Slurm backups are off for this lab;
# those modules are not instantiated.
# The module wait for soperator-activechecks is unconditional (240m). See
# 04-soperator-flux-overlay.tf — that patches Flux values so the install hook
# does not block on Slurm jobs that never get a status write here.

module "slurm" {
  depends_on = [module.fluxcd, terraform_data.platform_k8s_wipe]

  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/slurm?ref=soperator-v4.1.8-1"

  # --- Basic identities & cluster ---
  cluster_name        = local.s.cluster_name
  flux_namespace      = "flux-system"
  iam_project_id      = local.s.iam_project_id
  iam_tenant_id       = local.s.iam_tenant_id
  k8s_cluster_context = local.infra.k8s_cluster_context
  k8s_cluster_id      = local.infra.k8s_cluster_id
  name                = "soperator"
  region              = local.s.region

  # --- Operator versions & maintenance ---
  maintenance                    = "none"
  maintenance_ignore_node_groups = ["controller"]
  operator_stable                = true
  operator_version               = "4.1.8"

  # --- Worker/nodegroup/node configuration ---
  cuda_version                 = local.s.cuda_version
  node_count                   = local.s.node_count
  shared_memory_size_gibibytes = 64
  topology                     = local.s.topology
  use_preinstalled_gpu_drivers = local.s.use_preinstalled_gpu_drivers
  worker_nodesets              = local.s.worker_nodesets

  # --- Storage & filesystems ---
  controller_state_on_filestore = false
  filestores                    = local.s.filestores
  nfs = {
    enabled    = false
    path       = null
    host       = null
    mount_path = null
  }
  nfs_in_k8s = {
    enabled         = false
    version         = null
    use_stable_repo = true
    size_gibibytes  = null
    storage_class   = null
    threads         = null
  }
  nfs_node_group_enabled = false

  # --- Security & access ---
  login_allocation_id   = local.s.login_allocation_id
  login_on_worker_nodes = local.s.login_on_worker_nodes
  login_public_ip       = local.s.login_public_ip
  login_ssh_root_public_keys = [
    chomp(file(pathexpand(var.slurm_login_ssh_root_public_key_path))),
  ]
  login_sshd_config_map_ref_name   = ""
  sssd_conf_secret_ref_name        = ""
  sssd_ldap_ca_config_map_ref_name = ""
  sssd_enabled                     = false
  tailscale_enabled                = false
  use_default_apparmor_profile     = true
  worker_sshd_config_map_ref_name  = ""

  # --- Partitioning, health checks, & resources ---
  resources                 = local.s.resources
  slurm_accounting_config   = {}
  slurm_health_check_config = null
  slurm_nodesets_partitions = [
    {
      name         = "main"
      is_all       = true
      nodeset_refs = []
      config       = "Default=YES PriorityTier=10 PreemptMode=OFF MaxTime=INFINITE State=UP OverSubscribe=YES"
    },
    {
      name         = "hidden"
      is_all       = true
      nodeset_refs = []
      config       = "Default=NO PriorityTier=10 PreemptMode=OFF Hidden=YES MaxTime=INFINITE State=UP OverSubscribe=YES"
    },
  ]
  slurm_partition_config_type = "default"
  slurm_partition_raw_config  = []
  slurmdbd_config             = {}

  # --- Monitoring, reporting, and integrations ---
  accounting_enabled  = false
  active_checks_scope = "essential"
  exporter_enabled    = true
  public_o11y_enabled = false
  rest_enabled        = true
  soperator_notifier  = { enabled = false }
  telemetry_enabled   = true

  # --- Backup configuration ---
  backups_enabled = false
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
