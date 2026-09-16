#!/usr/bin/env bash
# Who holds the two H100s. Node column is the Nebius GPU dashboard legend.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "=== workers ==="
k -n soperator get nodeset worker
k -n soperator get pods -l slurm.nebius.ai/worker=true -o wide 2>/dev/null \
  || echo "  (none — expected in task 3)"
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
if k -n "${NS}" get deploy vllm-base >/dev/null 2>&1; then
  k -n "${NS}" get pods,ingress -l demo=task-3 -o wide
else
  echo "  Task 3 vLLM not applied"
fi
ip="$(k -n task2-ingress get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
echo "  LB ${ip:-not ready}"
echo "  A ${HOST_BASE}  →  ${ip:-<task-2/01-ingress.sh>}"
echo "  A ${HOST_DOLLY} →  ${ip:-<task-2/01-ingress.sh>}"
echo
echo "=== Flux ==="
k -n flux-system get helmrelease soperator-fluxcd \
  -o jsonpath='soperator-fluxcd  suspend={.spec.suspend}{"\n"}'
