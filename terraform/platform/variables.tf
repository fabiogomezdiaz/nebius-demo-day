variable "kubeconfig_path" {
  description = "Local kubeconfig path. Written by infra 05-kubeconfig.tf."
  type        = string
}

variable "slurm_login_ssh_root_public_key_path" {
  description = "Path to an SSH public key authorized as root on Slurm login nodes. ~ is expanded."
  type        = string
  nullable    = false
}
