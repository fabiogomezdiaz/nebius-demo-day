#!/usr/bin/env bash
# Shared kubeconfig + kubectl for task-2 scripts. Source this; do not run it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"
HOST="quen-lora-dolly.fabiogomezdiaz.app"
K8S="${ROOT}/task-2/k8s"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./task-1/02-apply_infra.sh first." >&2
  exit 1
fi

k() { kubectl --kubeconfig "${KUBECONFIG}" "$@"; }

# Server-side apply so these stubs only own the fields they set (replicas / suspend).
apply() { k apply --server-side --force-conflicts -f "$1"; }
