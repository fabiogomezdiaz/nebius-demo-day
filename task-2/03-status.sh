#!/usr/bin/env bash
# Who holds the two H100s, and is the public hostname up.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "=== workers ==="
k -n soperator get nodeset worker
k -n soperator get pods -l slurm.nebius.ai/worker=true -o wide
echo
echo "=== GPU pods ==="
k get pods -A -o json | jq -r '
  [
    .items[] as $p
    | $p.spec.containers[]?
    | ((.resources.requests // {})["nvidia.com/gpu"]
        // (.resources.limits // {})["nvidia.com/gpu"]) as $gpu
    | select($gpu != null)
    | "  \($p.metadata.namespace)/\($p.metadata.name)  node=\($p.spec.nodeName // "-")  gpu=\($gpu)  \($p.status.phase)"
  ]
  | if length == 0 then "  (none)" else .[] end
'
echo
echo "=== vLLM / Ingress ==="
if k -n task2-inference get deploy vllm >/dev/null 2>&1; then
  k -n task2-inference get pods,ingress -l app=vllm -o wide
else
  echo "  vLLM not applied"
fi
ip="$(k -n task2-ingress get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
echo "  LB ${ip:-not ready}   A ${HOST} → ${ip:-<01-ingress.sh>}"
echo
echo "=== Flux ==="
k -n flux-system get helmrelease soperator-fluxcd \
  -o jsonpath='soperator-fluxcd  suspend={.spec.suspend}{"\n"}'
