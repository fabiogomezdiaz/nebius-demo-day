# This stack is Nebius cloud only: filestore, MK8s, node groups, kubeconfig.
# Kubernetes operators live in terraform/platform. CRs and login.sh in terraform/workloads.

provider "nebius" {
  domain            = "api.eu.nebius.cloud:443"
  timeout           = "10m"
  per_retry_timeout = "1m"
  retries           = 10
}

provider "units" {}

provider "string-functions" {}
