#!/usr/bin/env bash
# Destroy terraform/platform (Flux, Soperator, GPU Operator).
# Terraform helm uninstall leaves Flux HelmReleases (helm.sh/resource-policy: keep).
# After terraform destroy, this script wipes those leftovers on the live cluster.
# Does not destroy MK8s/filestore. Run after workloads; infra is optional after this.
# Terraform will print a plan and wait for yes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"
PLATFORM="${ROOT}/terraform/platform"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${CLUSTER}/.envrc" ]]; then
  echo "Missing ${CLUSTER}/.envrc — run ./scripts/01-seed_envrc.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Platform destroy talks to the cluster." >&2
  exit 1
fi

cd "${CLUSTER}"
set +u
# shellcheck disable=SC1091
source ./.envrc
set -u

cd "${PLATFORM}"
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
  echo "Destroying terraform/platform (you will be asked to type yes)..."
  terraform destroy "$@"
else
  echo "Platform Terraform state is empty; skipping terraform destroy."
fi

echo
echo "Removing Flux/Soperator leftovers Terraform cannot uninstall..."
export K8S_CLUSTER_CONTEXT="${K8S_CLUSTER_CONTEXT:-$(kubectl --kubeconfig "${KUBECONFIG}" config current-context)}"
"${PLATFORM}/scripts/platform_k8s_wipe.sh"

echo
echo "Platform Kubernetes is gone. MK8s/filestore are still up."
echo "Reinstall: ./scripts/03-apply_platform.sh"
echo "Or destroy infra: ./scripts/07-destroy_infra.sh"
