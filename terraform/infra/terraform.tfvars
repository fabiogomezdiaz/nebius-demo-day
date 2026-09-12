#----------------------------------------------------------------------------------------------------------------------#
# Demo Day overlay for Soperator Terraform recipe soperator-v4.1.8-1
#
# Apply from this directory. terraform init fetches Soperator modules from
# github.com/nebius/nebius-solutions-library @ soperator-v4.1.8-1.
# Lab constants (filestore sizes, Slurm flags, partitions) are hardcoded in .tf.
#
# ./scripts/01-seed_envrc.sh writes:
#   slurm_login_ssh_root_public_keys  (from ~/.ssh/id_rsa.pub)
#   terraform/infra/.envrc            (tenant / project / region)
#----------------------------------------------------------------------------------------------------------------------#

company_name = "fabio-demo"

#----------------------------------------------------------------------------------------------------------------------#
# Nodesets — CPU: system 4×8 + login 16 + controller 4 = 6 nodes / 52 vCPU.
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
# - do NOT set infiniband_fabric (that creates nebius_compute_v1_gpu_cluster)
# - stock k8s gpu_fabric_validation.tf requires gpu_cluster.id or fabric on every
#   GPU preset. This preset is gpu_cluster_compatible = false, so the id is never
#   attached to the MK8s node group. Empty/null fails the stock check.
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
      size_gibibytes       = 512
      block_size_kibibytes = 4
    }
    gpu_cluster = {
      id = "ethernet-not-attached"
    }
    preemptible                    = null
    features                       = null
    create_partition               = null
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

# Seeded by ./scripts/01-seed_envrc.sh from SSH_PUBKEY_PATH (default ~/.ssh/id_rsa.pub).
slurm_login_ssh_root_public_keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCs+xAx8kJDIlMrEcSvy5jzr8yiGMy/qf6TPaZp89/egcchrZG0jofsUMMbeAE7aW7yOyYL1eAdqseBSzH7eqYCULa/iHKhHPVvYC5+V8TO704ok7IBJBpjnwSQZUHcoNtijLhIolYNWImbd77GF+CFd9iHevr9RvW+22BrxjdLKo1pQxDkiTgVbGMR5sbJxuWlrS1LtD7OeuQHT+9QzaW0T18BxEL9VcfU7HffEtireSOAy0UEvzCDVQf8QK4d7e+Bzw9uE2H30AKEncZfWo/ls1NxU5bL1VpCvYPWpNw1/fRROJldOc0lokZk6uUDG8L2/JtIIQbb0YRN5IXpgmAU2QsnkxcKmEN7wn4a9m3nkgXkujaOFblRGAmjKWg55d84AZ13FpCGjOZwqcu8nOaVAcVDBGuR9e2DMEVwCg1WPd9GgU5yJTBnnpaKIqEVyNpCEpeMs5nx4hbxjtcIt8zdIxd98wSJhUfSs/64yzMoK+b2mo7qJP5PDYnfn90uBhM= fabiogomezdiaz@mbpmax.local",
]
