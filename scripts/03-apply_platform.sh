#!/usr/bin/env bash
# Apply terraform/platform: Flux (Soperator installer), Soperator/Slurm,
# NVIDIA GPU Operator. Then apply terraform/workloads (login.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"
PLATFORM="${ROOT}/terraform/platform"
WORKLOADS="${ROOT}/terraform/workloads"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${CLUSTER}/.envrc" ]]; then
  echo "Missing ${CLUSTER}/.envrc — run ./scripts/01-seed_envrc.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./scripts/02-apply_infra.sh first." >&2
  exit 1
fi

apply_stack() {
  local dir="$1"
  shift
  cd "${dir}"
  set +u
  # shellcheck disable=SC1091
  if [[ -f ./.envrc ]]; then
    source ./.envrc
  else
    source ./envrc.example
  fi
  set -u
  terraform init -reconfigure
  terraform apply "$@"
}

echo "Applying platform (Flux + Soperator + GPU Operator)..."
cd "${CLUSTER}"
set +u
# shellcheck disable=SC1091
source ./.envrc
set -u

apply_stack "${PLATFORM}"

if [[ -f "${WORKLOADS}/versions.tf" ]]; then
  echo "Applying workloads (login.sh)..."
  apply_stack "${WORKLOADS}"
else
  echo "Skipping terraform/workloads (stack not in this checkout)."
fi

cd "${ROOT}"

echo
echo "SSH: terraform/workloads/login.sh -k <ssh-private-key>"
echo "Then: ./scripts/04-sync_workloads.sh <ssh-private-key> [login-host]"
