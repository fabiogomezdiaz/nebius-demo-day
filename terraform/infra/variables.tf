variable "region" {
  description = "Region of the project."
  type        = string
  nullable    = false
}

variable "iam_project_id" {
  description = "ID of the IAM project."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.iam_project_id, "project-")
    error_message = "ID of the IAM project must start with `project-`."
  }
}
data "nebius_iam_v1_project" "this" {
  id = var.iam_project_id
}

variable "iam_tenant_id" {
  description = "ID of the IAM tenant."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.iam_tenant_id, "tenant-")
    error_message = "ID of the IAM tenant must start with `tenant-`."
  }
}

variable "vpc_subnet_id" {
  description = "ID of VPC subnet."
  type        = string

  validation {
    condition     = startswith(var.vpc_subnet_id, "vpcsubnet-")
    error_message = "The ID of the VPC subnet must start with `vpcsubnet-`."
  }
}
data "nebius_vpc_v1_subnet" "this" {
  id = var.vpc_subnet_id
}

variable "company_name" {
  description = "Name of the company. It is used for naming Slurm & K8s clusters."
  type        = string

  validation {
    condition = (
      length(var.company_name) >= 1 &&
      length(var.company_name) <= 32 &&
      length(regexall("^[a-z][a-z\\d\\-]*[a-z\\d]+$", var.company_name)) == 1
    )
    error_message = <<EOF
      The company name must:
      - be 1 to 32 characters long
      - start with a letter
      - end with a letter or digit
      - consist of letters, digits, or hyphens (-)
      - contain only lowercase letters
    EOF
  }
}

variable "slurm_login_ssh_root_public_keys" {
  description = "Authorized keys accepted for connecting to Slurm login nodes via SSH as 'root' user."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.slurm_login_ssh_root_public_keys) >= 1
    error_message = "At least one SSH public key must be provided."
  }

  validation {
    condition     = alltrue([for k in var.slurm_login_ssh_root_public_keys : length(k) > 0])
    error_message = "SSH public keys must not be empty strings."
  }
}
