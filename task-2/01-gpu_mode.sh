#!/usr/bin/env bash
# Flip the two H100s between Task 1 (Slurm workers=2) and Task 2 (workers=1 + vLLM).
# Does not destroy MK8s, Soperator, login, or the jail. GPU node VMs stay up.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"
MODE="${1:-}"
VLLM_MANIFEST="${ROOT}/task-2/k8s/vllm.yaml"
WAIT_WORKERS_SECONDS="${WAIT_WORKERS_SECONDS:-300}"
WAIT_VLLM_SECONDS="${WAIT_VLLM_SECONDS:-900}"

usage() {
  cat >&2 <<'EOF'
Usage: ./task-2/01-gpu_mode.sh <serve|train|status>

  serve   Scale Soperator workers to 1 (free one H100), then apply vLLM.
  train   Delete vLLM, then scale Soperator workers back to 2.
  status  Show worker pods, GPU allocation, and vLLM.

Infra stays. Flux is patched so it does not put replicas=2 back after 5 minutes.
EOF
  exit 1
}

if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./task-1/02-apply_infra.sh first." >&2
  exit 1
fi

kubectl_bin() {
  kubectl --kubeconfig "${KUBECONFIG}" "$@"
}

worker_running_count() {
  kubectl_bin -n soperator get pods -l slurm.nebius.ai/worker=true \
    --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' '
}

vllm_running() {
  kubectl_bin -n soperator get deploy vllm --ignore-not-found -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true
}

print_status() {
  echo "=== NodeSet ==="
  kubectl_bin -n soperator get nodeset worker
  echo
  echo "=== Slurm worker pods ==="
  kubectl_bin -n soperator get pods -l slurm.nebius.ai/worker=true -o wide
  echo
  echo "=== GPU allocation (worker nodes) ==="
  kubectl_bin get nodes -l slurm.nebius.ai/nodeset-name=worker \
    -o 'custom-columns=NAME:.metadata.name,GPU_ALLOC:.status.allocatable.nvidia\.com/gpu'
  echo
  kubectl_bin get pods -A -o json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('GPU pods:')
found = False
for p in d['items']:
    for c in p['spec'].get('containers', []):
        res = c.get('resources') or {}
        req = res.get('requests') or {}
        lim = res.get('limits') or {}
        gpu = req.get('nvidia.com/gpu') or lim.get('nvidia.com/gpu')
        if gpu:
            found = True
            md = p['metadata']
            name = md['namespace'] + '/' + md['name']
            node = p['spec'].get('nodeName')
            phase = p['status']['phase']
            print('  %s node=%s gpu=%s phase=%s' % (name, node, gpu, phase))
if not found:
    print('  (none)')
"
  echo
  echo "=== vLLM ==="
  if kubectl_bin -n soperator get deploy vllm >/dev/null 2>&1; then
    kubectl_bin -n soperator get deploy,svc,pods -l app=vllm -o wide
  else
    echo "not applied"
  fi
}

set_worker_replicas() {
  local n="$1"
  echo "Setting Soperator worker replicas=${n} (ConfigMap + HelmRelease + NodeSet)"

  python3 - "${n}" <<'PY'
import json, re, subprocess, sys

n = sys.argv[1]
cm = json.loads(
    subprocess.check_output(
        ["kubectl", "--kubeconfig", __import__("os").environ["KUBECONFIG"],
         "-n", "flux-system", "get", "cm", "terraform-fluxcd-values", "-o", "json"]
    )
)
text = cm["data"]["values.yaml"]
pat = (
    r"(      - name: worker\n"
    r"        annotations:\n"
    r"          slurm\.nebius\.ai/parental-cluster-ref: soperator\n"
    r"\n"
    r"        replicas: )\d+"
)
new, count = re.subn(pat, r"\g<1>" + n, text, count=1)
if count != 1:
    sys.exit(f"expected to patch worker replicas once, got {count}")
cm["data"]["values.yaml"] = new
md = cm.setdefault("metadata", {})
for k in ("resourceVersion", "uid", "creationTimestamp", "managedFields"):
    md.pop(k, None)
subprocess.run(
    ["kubectl", "--kubeconfig", __import__("os").environ["KUBECONFIG"], "apply", "-f", "-"],
    input=json.dumps(cm),
    text=True,
    check=True,
)
PY

  kubectl_bin -n flux-system patch helmrelease flux-system-soperator-fluxcd-nodesets --type json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/values/nodesets/0/replicas\",\"value\":${n}}]" >/dev/null

  kubectl_bin -n soperator patch nodeset worker --type merge \
    -p "{\"spec\":{\"replicas\":${n}}}" >/dev/null
}

wait_workers() {
  local n="$1"
  local deadline=$((SECONDS + WAIT_WORKERS_SECONDS))
  echo "Waiting for ${n} Running worker pod(s) (timeout ${WAIT_WORKERS_SECONDS}s)"
  while (( SECONDS < deadline )); do
    local got
    got="$(worker_running_count)"
    if [[ "${got}" == "${n}" ]]; then
      # Scale-down: worker-1 must actually be gone, not just "1 running".
      if [[ "${n}" == "1" ]] && kubectl_bin -n soperator get pod worker-1 >/dev/null 2>&1; then
        echo "  worker-1 still terminating..."
        sleep 5
        continue
      fi
      echo "Workers ready (${n})."
      return 0
    fi
    echo "  running=${got} want=${n}"
    sleep 5
  done
  echo "Timed out waiting for ${n} worker pod(s)." >&2
  kubectl_bin -n soperator get pods -l slurm.nebius.ai/worker=true -o wide >&2 || true
  exit 1
}

delete_vllm() {
  if kubectl_bin -n soperator get deploy vllm >/dev/null 2>&1; then
    echo "Deleting vLLM"
    kubectl_bin delete -f "${VLLM_MANIFEST}" --wait=true --timeout=180s
  else
    echo "vLLM not applied"
  fi
}

apply_vllm() {
  echo "Applying vLLM (first image pull can take several minutes)"
  kubectl_bin apply -f "${VLLM_MANIFEST}"
  echo "Waiting for vLLM Available (timeout ${WAIT_VLLM_SECONDS}s)"
  if ! kubectl_bin -n soperator rollout status deploy/vllm --timeout="${WAIT_VLLM_SECONDS}s"; then
    echo "vLLM did not become ready. Pods:" >&2
    kubectl_bin -n soperator get pods -l app=vllm -o wide >&2 || true
    kubectl_bin -n soperator describe pods -l app=vllm >&2 || true
    exit 1
  fi
}

print_serve_hint() {
  cat <<'EOF'

Task 2 mode: 1 Slurm worker + vLLM on the other H100.
Login SSH and /mnt/data are unchanged. A 2-node sbatch will sit PD until you run:
  ./task-2/01-gpu_mode.sh train

Query (laptop):
  kubectl --kubeconfig terraform/kubeconfig -n soperator port-forward svc/vllm 8000:8000
  curl -s http://127.0.0.1:8000/v1/models | jq .
  curl -s http://127.0.0.1:8000/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{"model":"dolly","messages":[{"role":"user","content":"What is Databricks Dolly?"}],"max_tokens":128}'

Base model (no adapters) is served as qwen25-7b; LoRA as dolly.
EOF
}

case "${MODE}" in
  status)
    print_status
    ;;
  serve)
    delete_vllm
    set_worker_replicas 1
    wait_workers 1
    apply_vllm
    print_status
    print_serve_hint
    ;;
  train)
    delete_vllm
    set_worker_replicas 2
    wait_workers 2
    print_status
    echo
    echo "Task 1 mode: both H100s are Slurm workers again. sbatch /mnt/data/nebius-demo/task-1/train.sbatch"
    ;;
  *)
    usage
    ;;
esac
