#!/usr/bin/env bash
# Apply terraform/infra: MK8s, node groups, filestore, kubeconfig.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"

if [[ ! -f "${CLUSTER}/.envrc" ]]; then
  echo "Missing ${CLUSTER}/.envrc — run ./scripts/01-seed_envrc.sh first." >&2
  exit 1
fi

cd "${CLUSTER}"
set +u
# shellcheck disable=SC1091
source ./.envrc
set -u

terraform init -reconfigure
terraform apply "$@"

echo
echo "Next: ./scripts/03-apply_platform.sh"
