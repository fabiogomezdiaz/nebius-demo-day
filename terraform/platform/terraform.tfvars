# Seeded by ./scripts/01-seed_tfvars.sh.
kubeconfig_path = "../kubeconfig"

# Path to a .pub file. Terraform reads the key and installs it on the login node.
# Override with SSH_PUBKEY_PATH when seeding (default ~/.ssh/id_rsa.pub).
slurm_login_ssh_root_public_key_path = "~/.ssh/id_rsa.pub"
