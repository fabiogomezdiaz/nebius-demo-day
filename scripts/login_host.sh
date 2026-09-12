#!/usr/bin/env bash
# Print the Slurm login LoadBalancer IP (soperator-login-svc).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./scripts/02-apply_infra.sh first." >&2
  exit 1
fi

ip="$(kubectl --kubeconfig "${KUBECONFIG}" -n soperator get svc soperator-login-svc \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
if [[ -z "${ip}" ]]; then
  echo "Could not read soperator-login-svc LoadBalancer IP. Is platform applied?" >&2
  exit 1
fi
printf '%s\n' "${ip}"
