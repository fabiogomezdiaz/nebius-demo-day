#!/usr/bin/env bash
# One-time: install ingress-nginx so the cluster has a public LoadBalancer.
# MK8s ships with none. Does not apply the vLLM Ingress — that is 02-serve.sh.
# DNS is yours: A record HOST → the printed IP.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

CHART_VERSION="${INGRESS_NGINX_CHART_VERSION:-4.13.3}"
if ! command -v helm >/dev/null; then
  echo "helm is required (task-1/00-install_prereqs.sh)." >&2
  exit 1
fi

echo "Installing ingress-nginx in task2-ingress"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update ingress-nginx >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace task2-ingress --create-namespace \
  --version "${CHART_VERSION}" \
  --values "${K8S}/ingress-nginx-values.yaml" \
  --kubeconfig "${KUBECONFIG}" --wait --timeout 5m >/dev/null

echo "Waiting for LoadBalancer IP..."
k -n task2-ingress wait svc/ingress-nginx-controller \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' --timeout=180s >/dev/null
ip="$(k -n task2-ingress get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

echo
echo "A record:  ${HOST}  →  ${ip}"
echo "Then:      ./task-2/02-serve.sh"
echo "Tear down: ./task-2/04-destroy_ingress.sh"
