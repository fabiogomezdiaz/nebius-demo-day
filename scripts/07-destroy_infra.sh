#!/usr/bin/env bash
# Destroy terraform/infra (MK8s, node groups, filestore).
# Run last, after workloads and platform, so Kubernetes cleanup already ran.
# Terraform will print a plan and wait for yes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"

if [[ ! -f "${CLUSTER}/terraform.tfvars" ]]; then
  echo "Missing ${CLUSTER}/terraform.tfvars — run ./scripts/01-seed_tfvars.sh first." >&2
  exit 1
fi

export NEBIUS_IAM_TOKEN="$("${ROOT}/scripts/retry.sh" -- nebius iam get-access-token)"

cd "${CLUSTER}"
terraform init -reconfigure
if terraform state list 2>/dev/null | grep -q .; then
  echo "Destroying terraform/infra (you will be asked to type yes)..."
  terraform destroy "$@"
else
  echo "Infra Terraform state is empty; skipping terraform destroy."
fi

echo
echo "Infra destroy complete."
