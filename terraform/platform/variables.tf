variable "kubeconfig_path" {
  description = "Local kubeconfig path (TF_VAR_kubeconfig_path). Written by infra 06-kubeconfig.tf."
  type        = string
}

variable "region" {
  description = "Nebius region (TF_VAR_region)."
  type        = string
  default     = ""
}
