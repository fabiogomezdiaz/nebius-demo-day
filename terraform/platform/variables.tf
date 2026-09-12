variable "kubeconfig_path" {
  description = "Local kubeconfig path. Written by infra 05-kubeconfig.tf."
  type        = string
}

variable "slurm_login_ssh_root_public_keys" {
  description = "Authorized keys accepted for connecting to Slurm login nodes via SSH as 'root' user."
  type        = list(string)
  nullable    = false
}
