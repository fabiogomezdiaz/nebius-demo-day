# Soperator inputs come from infra local state.

data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.module}/../infra/terraform.tfstate"
  }
}

locals {
  infra     = data.terraform_remote_state.infra.outputs
  soperator = local.infra.soperator
}
