#!/usr/bin/env bash
# Apply terraform/platform: Flux (Soperator installer), Soperator/Slurm,
# NVIDIA GPU Operator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${ROOT}/terraform/platform"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${PLATFORM}/terraform.tfvars" ]]; then
  echo "Missing ${PLATFORM}/terraform.tfvars — run ./task-1/01-seed_tfvars.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./task-1/02-apply_infra.sh first." >&2
  exit 1
fi

export NEBIUS_IAM_TOKEN="$("${ROOT}/task-1/retry.sh" -- nebius iam get-access-token)"

cd "${PLATFORM}"
terraform init -reconfigure
terraform apply "$@"

cd "${ROOT}"

echo
echo "Next: ./task-1/04-sync.sh"
echo "Then: ./task-1/05-login.sh"
