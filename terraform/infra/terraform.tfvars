#----------------------------------------------------------------------------------------------------------------------#
# Demo Day overlay for Soperator Terraform recipe soperator-v4.1.8-1
#
# Apply from this directory. terraform init fetches Soperator modules from
# github.com/nebius/nebius-solutions-library @ soperator-v4.1.8-1.
# Node groups, filestore sizes, and Slurm flags are hardcoded in .tf.
#
# ./scripts/01-seed_envrc.sh writes:
#   slurm_login_ssh_root_public_keys  (from ~/.ssh/id_rsa.pub)
#   terraform/infra/.envrc            (tenant / project / region)
#----------------------------------------------------------------------------------------------------------------------#

company_name = "fabio-demo"

# Seeded by ./scripts/01-seed_envrc.sh from SSH_PUBKEY_PATH (default ~/.ssh/id_rsa.pub).
slurm_login_ssh_root_public_keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCs+xAx8kJDIlMrEcSvy5jzr8yiGMy/qf6TPaZp89/egcchrZG0jofsUMMbeAE7aW7yOyYL1eAdqseBSzH7eqYCULa/iHKhHPVvYC5+V8TO704ok7IBJBpjnwSQZUHcoNtijLhIolYNWImbd77GF+CFd9iHevr9RvW+22BrxjdLKo1pQxDkiTgVbGMR5sbJxuWlrS1LtD7OeuQHT+9QzaW0T18BxEL9VcfU7HffEtireSOAy0UEvzCDVQf8QK4d7e+Bzw9uE2H30AKEncZfWo/ls1NxU5bL1VpCvYPWpNw1/fRROJldOc0lokZk6uUDG8L2/JtIIQbb0YRN5IXpgmAU2QsnkxcKmEN7wn4a9m3nkgXkujaOFblRGAmjKWg55d84AZ13FpCGjOZwqcu8nOaVAcVDBGuR9e2DMEVwCg1WPd9GgU5yJTBnnpaKIqEVyNpCEpeMs5nx4hbxjtcIt8zdIxd98wSJhUfSs/64yzMoK+b2mo7qJP5PDYnfn90uBhM= fabiogomezdiaz@mbpmax.local",
]
