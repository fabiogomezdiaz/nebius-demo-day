#!/usr/bin/env bash
# Apply terraform/infra: MK8s, node groups, filestore, kubeconfig.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"

if [[ ! -f "${CLUSTER}/terraform.tfvars" ]]; then
  echo "Missing ${CLUSTER}/terraform.tfvars — run ./task-1/01-seed_tfvars.sh first." >&2
  exit 1
fi

export NEBIUS_IAM_TOKEN="$("${ROOT}/task-1/retry.sh" -- nebius iam get-access-token)"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

cd "${CLUSTER}"
terraform init -reconfigure
terraform apply "$@"

echo
echo "Next: ./task-1/03-apply_platform.sh"
