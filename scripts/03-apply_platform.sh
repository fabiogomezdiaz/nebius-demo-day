#!/usr/bin/env bash
# Apply terraform/platform: Flux (Soperator installer), Soperator/Slurm,
# NVIDIA GPU Operator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${ROOT}/terraform/platform"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${PLATFORM}/terraform.tfvars" ]]; then
  echo "Missing ${PLATFORM}/terraform.tfvars — run ./scripts/01-seed_tfvars.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./scripts/02-apply_infra.sh first." >&2
  exit 1
fi

export NEBIUS_IAM_TOKEN="$("${ROOT}/scripts/retry.sh" -- nebius iam get-access-token)"

cd "${PLATFORM}"
terraform init -reconfigure
terraform apply "$@"

cd "${ROOT}"

echo
echo "Next: ./scripts/04-sync_workloads.sh"
echo "Then: ./scripts/05-login.sh"
