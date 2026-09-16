#!/usr/bin/env bash
# Apply terraform/platform: Flux (Soperator installer), Soperator/Slurm,
# NVIDIA GPU Operator. Also drops Task 2/3 vLLM if present and puts both
# H100s back on Slurm workers (training mode).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${ROOT}/terraform/platform"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${PLATFORM}/terraform.tfvars" ]]; then
  echo "Missing ${PLATFORM}/terraform.tfvars — run ./task-1/01-seed_tfvars.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./task-1/02-apply_infra.sh first." >&2
  exit 1
fi

export NEBIUS_IAM_TOKEN="$("${ROOT}/task-1/retry.sh" -- nebius iam get-access-token)"

cd "${PLATFORM}"
terraform init -reconfigure
terraform apply "$@"

cd "${ROOT}"

# Training needs worker-0 and worker-1. Task 2/3 may have paused Flux and
# scheduled vLLM on the H100s — undo that here, not in those folders.
K8S="${ROOT}/task-2/k8s"
K8S3="${ROOT}/task-3/k8s"
kubectl delete -f "${K8S}/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
kubectl delete -f "${K8S}/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null
kubectl delete -f "${K8S3}/ingress.yaml" --wait --timeout=60s --ignore-not-found >/dev/null
kubectl delete -f "${K8S3}/vllm.yaml" --wait --timeout=180s --ignore-not-found >/dev/null
kubectl apply --server-side --force-conflicts -f "${K8S}/flux-resume.yaml" >/dev/null
kubectl apply --server-side --force-conflicts -f "${K8S}/workers-2.yaml" >/dev/null
kubectl wait -n soperator --for=condition=Ready pod/worker-0 --timeout=300s >/dev/null
kubectl wait -n soperator --for=condition=Ready pod/worker-1 --timeout=300s >/dev/null

echo
echo "Workers: 2. Next: ./task-1/04-sync.sh then ./task-1/05-login.sh"
