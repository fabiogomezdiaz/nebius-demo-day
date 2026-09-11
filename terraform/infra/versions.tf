# Pin: git::https://github.com/nebius/nebius-solutions-library.git?ref=soperator-v4.1.8-1

terraform {
  required_version = ">=1.12.0"

  required_providers {
    nebius = {
      source  = "terraform-provider.storage.eu-north1.nebius.cloud/nebius/nebius"
      version = "= 0.5.230"
    }

    units = {
      source  = "dstaroff/units"
      version = ">=1.1.1"
    }

    string-functions = {
      source  = "random-things/string-functions"
      version = "0.5.0"
    }
  }
}
