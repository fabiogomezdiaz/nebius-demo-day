#!/usr/bin/env bash
# Remove the public LB. Does not touch vLLM, Soperator, or DNS.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "Destroying ingress-nginx"
k delete -f "${K8S}/ingress.yaml" --ignore-not-found --wait --timeout=60s >/dev/null

if command -v helm >/dev/null \
  && helm --kubeconfig "${KUBECONFIG}" -n task2-ingress status ingress-nginx >/dev/null 2>&1; then
  helm --kubeconfig "${KUBECONFIG}" uninstall ingress-nginx -n task2-ingress --wait --timeout 3m >/dev/null
fi
k delete ns task2-ingress --ignore-not-found --wait --timeout=120s >/dev/null
echo "Controller gone. vLLM in task2-inference is unchanged."
