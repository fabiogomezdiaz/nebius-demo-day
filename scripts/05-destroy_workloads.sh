#!/usr/bin/env bash
# Destroy terraform/workloads (login.sh).
# Run this before platform destroy. Terraform will print a plan and wait for yes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"
WORKLOADS="${ROOT}/terraform/workloads"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${CLUSTER}/.envrc" ]]; then
  echo "Missing ${CLUSTER}/.envrc — run ./scripts/01-seed_envrc.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Workloads destroy talks to the cluster." >&2
  exit 1
fi

cd "${CLUSTER}"
set +u
# shellcheck disable=SC1091
source ./.envrc
set -u

cd "${WORKLOADS}"
set +u
# shellcheck disable=SC1091
if [[ -f ./.envrc ]]; then
  source ./.envrc
else
  source ./envrc.example
fi
set -u

terraform init -reconfigure
if terraform state list 2>/dev/null | grep -q .; then
  echo "Destroying terraform/workloads (you will be asked to type yes)..."
  terraform destroy "$@"
else
  echo "Workloads Terraform state is empty; skipping terraform destroy."
fi

echo
echo "Next: ./scripts/06-destroy_platform.sh"
