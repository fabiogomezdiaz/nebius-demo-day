#!/usr/bin/env bash
# Apply terraform/platform: Flux (Soperator installer), Soperator/Slurm,
# NVIDIA GPU Operator, Training Operator, ArgoCD.
# Then apply terraform/workloads (login.sh, ConfigMap; MPIJob stays off).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${ROOT}/terraform/infra"
PLATFORM="${ROOT}/terraform/platform"
WORKLOADS="${ROOT}/terraform/workloads"
export KUBECONFIG="${KUBECONFIG:-${ROOT}/terraform/kubeconfig}"

if [[ ! -f "${CLUSTER}/.envrc" ]]; then
  echo "Missing ${CLUSTER}/.envrc — run ./scripts/01-seed_envrc.sh first." >&2
  exit 1
fi
if [[ ! -f "${KUBECONFIG}" ]]; then
  echo "Missing ${KUBECONFIG}. Run ./scripts/02-apply_infra.sh first." >&2
  exit 1
fi

apply_stack() {
  local dir="$1"
  shift
  cd "${dir}"
  set +u
  # shellcheck disable=SC1091
  if [[ -f ./.envrc ]]; then
    source ./.envrc
  else
    source ./envrc.example
  fi
  set -u
  terraform init -reconfigure
  terraform apply "$@"
}

echo "Applying platform (Flux + Soperator + GPU Operator + Training Operator + ArgoCD)..."
cd "${CLUSTER}"
set +u
# shellcheck disable=SC1091
source ./.envrc
set -u

apply_stack "${PLATFORM}"

if [[ -f "${WORKLOADS}/versions.tf" ]]; then
  echo "Applying workloads (login.sh + namespaces + ConfigMap; MPIJob off until GPUs are freed)..."
  apply_stack "${WORKLOADS}"
else
  echo "Skipping terraform/workloads (stack not in this checkout)."
fi

cd "${ROOT}"

if kubectl --kubeconfig "${KUBECONFIG}" --request-timeout=15s -n argocd get deploy argo-cd-argocd-server >/dev/null 2>&1; then
  echo "Waiting for ArgoCD server..."
  kubectl --kubeconfig "${KUBECONFIG}" -n argocd rollout status deploy/argo-cd-argocd-server --timeout=180s
else
  echo "ArgoCD deploy not present; skip wait."
fi

echo
echo "ArgoCD UI:  kubectl --kubeconfig ${KUBECONFIG} -n argocd port-forward svc/argo-cd-argocd-server 8080:80"
echo "Password:   kubectl --kubeconfig ${KUBECONFIG} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "Then open http://127.0.0.1:8080  (user admin)"
echo
echo "NCCL MPIJob: ./scripts/04-scale_slurm_gpu_workers.sh 0"
echo "  then terraform apply -var=enable_nccl_mpijob=true in terraform/workloads"
