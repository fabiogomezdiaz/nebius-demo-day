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
