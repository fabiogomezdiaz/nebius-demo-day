#!/usr/bin/env bash
# Shared kubeconfig + kubectl for task-3 scripts (01–03). Source this; do not run it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"
K8S="${ROOT}/task-3/k8s"
TASK2_K8S="${ROOT}/task-2/k8s"
NS="task3-inference"
HOST_BASE="quen-qwen25.fabiogomezdiaz.app"
HOST_DOLLY="quen-lora-dolly.fabiogomezdiaz.app"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./task-1/02-apply_infra.sh first." >&2
  exit 1
fi

k() { kubectl --kubeconfig "${KUBECONFIG}" "$@"; }

# Server-side apply so these stubs only own the fields they set (replicas / suspend).
apply() { k apply --server-side --force-conflicts -f "$1"; }
