#----------------------------------------------------------------------------------------------------------------------#
# Demo Day overlay for Soperator Terraform recipe soperator-v4.1.8-1
#
# This file is copied onto a cloned installations/example tree by
# scripts/bootstrap_soperator.sh. Do not point Terraform at this directory
# directly; it has no main.tf.
#
# Required edits before apply:
#   1. slurm_login_ssh_root_public_keys  -> your SSH public key
#   2. vendor/.../installations/demo-day/.envrc -> NEBIUS_TENANT_ID / PROJECT_ID
#----------------------------------------------------------------------------------------------------------------------#

company_name = "fabio-demo"
production   = false

#----------------------------------------------------------------------------------------------------------------------#
# Storage — new filesystems only. Do not attach another cluster's jail.
#----------------------------------------------------------------------------------------------------------------------#

controller_state_on_filestore = false

filestore_controller_spool = {
  spec = {
    size_gibibytes       = 128
    block_size_kibibytes = 4
    forbid_deletion      = false
  }
}

filestore_jail = {
  spec = {
    size_gibibytes       = 256
    block_size_kibibytes = 4
    forbid_deletion      = false
  }
}

filestore_jail_submounts = [{
  name       = "data"
  mount_path = "/mnt/data"
  spec = {
    size_gibibytes       = 512
    block_size_kibibytes = 4
    forbid_deletion      = false
  }
}]

filestore_accounting = {
  spec = {
    size_gibibytes       = 128
    block_size_kibibytes = 4
    forbid_deletion      = false
  }
}

nfs_in_k8s = {
  enabled         = true
  version         = "1.2.0"
  use_stable_repo = true
  size_gibibytes  = 372
  disk_type       = "NETWORK_SSD"
  filesystem_type = "ext4"
  threads         = 8
}

#----------------------------------------------------------------------------------------------------------------------#
# Slurm
#----------------------------------------------------------------------------------------------------------------------#

slurm_operator_version = "4.1.8"
slurm_operator_stable  = true

slurm_nodesets_partitions = [
  {
    name               = "main"
    is_all             = true
    slurm_nodeset_refs = []
    config             = "Default=YES PriorityTier=10 PreemptMode=OFF MaxTime=INFINITE State=UP OverSubscribe=YES"
  },
  {
    name               = "hidden"
    is_all             = true
    slurm_nodeset_refs = []
    config             = "Default=NO PriorityTier=10 PreemptMode=OFF Hidden=YES MaxTime=INFINITE State=UP OverSubscribe=YES"
  },
]

slurm_partition_config_type = "default"

#----------------------------------------------------------------------------------------------------------------------#
# Nodesets — CPU budget matches the invitation (8 CPU nodes / 64 vCPU).
# GPU workers are extra: 2 x 1xH100, no InfiniBand.
#----------------------------------------------------------------------------------------------------------------------#

slurm_nodeset_system = {
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

slurm_nodeset_controller = {
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

# KEY CHANGE vs stock recipe:
# - preset 1gpu-16vcpu-200gb (not 8gpu, not GPU-cluster compatible)
# - gpu_cluster = null  (do NOT set infiniband_fabric = "")
# - two nodes, autoscaling off
slurm_nodeset_workers = [
  {
    name = "worker"
    size = 2
    autoscaling = {
      enabled  = false
      min_size = 2
    }
    resource = {
      platform = "gpu-h100-sxm"
      preset   = "1gpu-16vcpu-200gb"
    }
    boot_disk = {
      type                 = "NETWORK_SSD"
      size_gibibytes       = 256
      block_size_kibibytes = 4
    }
    gpu_cluster = null
    preemptible = null
    features    = null
    create_partition = null
    ephemeral_nodes                = false
    initial_number_ephemeral_nodes = 1
    persistent_volume_claim_retention_policy = {
      when_deleted = "Delete"
      when_scaled  = "Delete"
    }
    node_local_jail_submounts = []
    node_local_image_disk = {
      enabled = false
    }
  },
]

use_preinstalled_gpu_drivers = true

slurm_nodeset_login = {
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

slurm_nodeset_accounting = {
  resource = {
    platform = "cpu-d3"
    preset   = "8vcpu-32gb"
  }
  boot_disk = {
    type                 = "NETWORK_SSD"
    size_gibibytes       = 128
    block_size_kibibytes = 4
  }
}

slurm_nodeset_nfs = {
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

slurm_login_public_ip = true
tailscale_enabled     = false
slurm_sssd_enabled    = false
slurm_sssd_conf_secret_ref_name        = ""
slurm_sssd_ldap_ca_config_map_ref_name = ""

# REPLACE with your real SSH public key before apply.
slurm_login_ssh_root_public_keys = [
  "ssh-ed25519 REPLACE_ME_WITH_YOUR_PUBLIC_KEY fabio@demo-day",
]

slurm_exporter_enabled = true

# Skip IB/NCCL fabric health checks that cannot pass on 1xH100 Ethernet nodes.
active_checks_scope = "essential"

# 1024 GiB shm is sized for 8xH100 / 1600 GiB RAM nodes. This preset has 200 GiB RAM.
slurm_shared_memory_size_gibibytes = 64
slurm_topology_block_size          = null
maintenance_ignore_node_groups     = ["controller", "nfs"]

telemetry_enabled         = true
dcgm_job_mapping_enabled  = true
soperator_notifier = {
  enabled = false
}

# Assignment / known recipe issue.
public_o11y_enabled = false

accounting_enabled = true

backups_enabled             = "force_disable"
backups_password            = "password"
backups_schedule            = "@daily-random"
backups_prune_schedule      = "@daily-random"
backups_retention = {
  keepDaily = 7
}
cleanup_bucket_on_destroy = false

k8s_version = 1.35

nvidia_config_lines = [
  "options nvidia NVreg_RestrictProfilingToAdminUsers=0",
  "options nvidia NVreg_EnableStreamMemOPs=1",
  "options nvidia NVreg_RegistryDwords=\"PeerMappingOverride=1;\"",
]
