#!/usr/bin/env bash
# Task 2 mode: free one H100, serve LoRA (dolly) + base (qwen25-7b) with vLLM.
# Does not destroy MK8s, Soperator, login, or the jail.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "Serve: workers=1 + vLLM"
# Recreate vLLM so a leftover pod cannot pin the GPU we need.
# Task 3 holds both GPUs; drop it before workers can return to 1.
k delete -f "${ROOT}/task-3/k8s/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
k delete -f "${ROOT}/task-3/k8s/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null
k delete -f "${K8S}/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
k delete -f "${K8S}/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null

# Pause Flux, then set NodeSet replicas from YAML (a live scale is reverted otherwise).
apply "${K8S}/flux-pause.yaml" >/dev/null
apply "${K8S}/workers-1.yaml" >/dev/null
echo "Waiting for worker-1 to go away..."
if k -n soperator get pod worker-1 >/dev/null 2>&1; then
  k wait -n soperator --for=delete pod/worker-1 --timeout=300s >/dev/null
fi
k wait -n soperator --for=condition=Ready pod/worker-0 --timeout=300s >/dev/null

k apply -f "${K8S}/namespace.yaml" >/dev/null
# Retain PVs keep claimRef after PVC delete; drop it so data.yaml can rebind.
if [[ "$(k get pv jail-submount-data-task2-pv -o jsonpath='{.status.phase}' 2>/dev/null || true)" == "Released" ]]; then
  k patch pv jail-submount-data-task2-pv --type json --patch-file "${K8S}/pv-unbind.yaml" >/dev/null
fi
k apply -f "${K8S}/data.yaml" >/dev/null

# First image pull can take several minutes. enableServiceLinks: false in the
# manifest — a Service named vllm would otherwise inject VLLM_PORT and crash.
echo "Waiting for vLLM (image pull can take a few minutes)..."
k apply -f "${K8S}/vllm.yaml" >/dev/null
k -n task2-inference rollout status deploy/vllm --timeout=900s
k apply -f "${K8S}/ingress.yaml" >/dev/null

echo
k -n soperator get pods -l slurm.nebius.ai/worker=true -o wide
k -n task2-inference get pods,ingress -l app=vllm -o wide
ip="$(k -n task2-ingress get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
echo
echo "Models: dolly (LoRA) and qwen25-7b (base)."
echo "  kubectl --kubeconfig terraform/kubeconfig -n task2-inference port-forward svc/vllm 8000:8000"
echo "  curl -s http://${HOST}/v1/models   # A ${HOST} → ${ip:-<01-ingress.sh>}"
echo "Back to train: ./task-1/03-apply_platform.sh"
