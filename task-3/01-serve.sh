#!/usr/bin/env bash
# Task 3 mode: free both H100s, serve base and LoRA as two vLLM processes.
# Does not destroy MK8s, Soperator, login, or the jail. Live sinfo has no GPUs.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "Compare: workers=0 + vLLM base + vLLM dolly"
# Task 2 holds one GPU; drop it before workers can go to 0.
k delete -f "${TASK2_K8S}/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
k delete -f "${TASK2_K8S}/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null
k delete -f "${K8S}/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
k delete -f "${K8S}/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null

apply "${K8S}/flux-pause.yaml" >/dev/null
apply "${K8S}/workers-0.yaml" >/dev/null
echo "Waiting for worker-0 and worker-1 to go away..."
for pod in worker-0 worker-1; do
  if k -n soperator get pod "${pod}" >/dev/null 2>&1; then
    k wait -n soperator --for=delete "pod/${pod}" --timeout=300s >/dev/null
  fi
done

k apply -f "${K8S}/namespace.yaml" >/dev/null
for pv in jail-submount-data-task3-base-pv jail-submount-data-task3-dolly-pv; do
  if [[ "$(k get pv "${pv}" -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Released" ]]; then
    k patch pv "${pv}" --type json --patch-file "${K8S}/pv-unbind.yaml" >/dev/null
  fi
done
k apply -f "${K8S}/data.yaml" >/dev/null

# First image pull on the second GPU node can take several minutes.
echo "Waiting for both vLLM Deployments..."
k apply -f "${K8S}/vllm.yaml" >/dev/null
k -n "${NS}" rollout status deploy/vllm-base --timeout=900s
k -n "${NS}" rollout status deploy/vllm-dolly --timeout=900s
k apply -f "${K8S}/ingress.yaml" >/dev/null

echo
k -n soperator get pods -l slurm.nebius.ai/worker=true -o wide
k -n "${NS}" get pods -l demo=task-3 -o wide
ip="$(k -n task2-ingress get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
echo
echo "Dashboard legend is the node column above (one VM per model)."
echo "  base   http://${HOST_BASE}    model=qwen25-7b"
echo "  dolly  http://${HOST_DOLLY}   model=dolly"
echo "  A ${HOST_BASE}  →  ${ip:-<task-2/01-ingress.sh>}"
echo "  A ${HOST_DOLLY} →  ${ip:-<task-2/01-ingress.sh>}"
echo "Compare: ./task-3/03-compare.sh"
echo "Load:    ./task-4/01-load.sh"
echo "Back to train: ./task-1/03-apply_platform.sh"
