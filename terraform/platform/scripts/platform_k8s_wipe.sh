#!/usr/bin/env bash
# Tear down Flux-managed Soperator and other platform Kubernetes leftovers.
# Idempotent: if the cluster is already clean, prints that and exits 0.
# Never fetches remote manifests (that is what hung on a second destroy).
set -euo pipefail

CTX="${K8S_CLUSTER_CONTEXT:-}"

k() {
  local args=(--request-timeout=20s)
  if [[ -n "${CTX}" ]]; then
    args+=(--context "${CTX}")
  fi
  kubectl "${args[@]}" "$@"
}

ns_exists() {
  k get ns "$1" >/dev/null 2>&1
}

crd_exists() {
  k get crd "$1" >/dev/null 2>&1
}

if ! k version >/dev/null 2>&1; then
  echo "Cluster unreachable; skipping platform Kubernetes wipe."
  exit 0
fi

NAMESPACES=(
  soperator
  soperator-system
  soperator-checks
  kruise-system
  kruise-daemon-config
  monitoring-system
  logs-system
  cert-manager-system
  security-profiles-operator-system
  storage-system
  nvidia-gpu-operator
  kubeflow
  argocd
  flux-system
)

CRD_PATTERN='slurm\.nebius\.ai|kruise\.io|victoriametrics|cert-manager\.io|argoproj\.io|kubeflow\.org|security-profiles-operator|toolkit\.fluxcd\.io|monitoring\.coreos\.com'
WEBHOOK_PATTERN='kruise|victoria|training-operator|cert-manager|soperator|flux'

platform_ns=()
for ns in "${NAMESPACES[@]}"; do
  if ns_exists "${ns}"; then
    platform_ns+=("${ns}")
  fi
done

platform_crds="$(k get crd -o name 2>/dev/null | grep -iE "${CRD_PATTERN}" || true)"
platform_webhooks="$(k get mutatingwebhookconfiguration,validatingwebhookconfiguration -o name 2>/dev/null \
  | grep -iE "${WEBHOOK_PATTERN}" || true)"

if [[ ${#platform_ns[@]} -eq 0 && -z "${platform_crds}" && -z "${platform_webhooks}" ]]; then
  echo "Platform Kubernetes already clean."
  k get ns
  exit 0
fi

echo "Wiping platform Kubernetes leftovers (Flux, Soperator, operators)..."

strip_ns() {
  local ns="$1" kind="$2"
  local obj
  ns_exists "${ns}" || return 0
  while read -r obj; do
    [[ -z "${obj}" ]] && continue
    k patch "${obj}" -n "${ns}" --type merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done < <(k get "${kind}" -n "${ns}" -o name --ignore-not-found 2>/dev/null || true)
}

# 1. HelmReleases (only if the CRD is still around)
if crd_exists helmreleases.helm.toolkit.fluxcd.io && ns_exists flux-system; then
  k -n flux-system delete helmrelease soperator-fluxcd --wait=false --ignore-not-found >/dev/null 2>&1 || true
  strip_ns flux-system helmrelease.helm.toolkit.fluxcd.io
fi

# 2. Login LoadBalancer + stuck activechecks helm hook
if ns_exists soperator-system; then
  k -n soperator-system scale deploy/soperator-controller-manager --replicas=0 >/dev/null 2>&1 || true
fi
if ns_exists soperator; then
  k -n soperator delete svc soperator-login-svc --wait=false --ignore-not-found >/dev/null 2>&1 || true
  k -n soperator delete job wait-for-active-checks --wait=false --ignore-not-found >/dev/null 2>&1 || true
  if crd_exists activechecks.slurm.nebius.ai; then
    k -n soperator delete activecheck --all --wait=false --ignore-not-found >/dev/null 2>&1 || true
  fi
  if crd_exists nodesets.slurm.nebius.ai; then
    k -n soperator delete nodeset --all --wait=false --ignore-not-found >/dev/null 2>&1 || true
  fi
  if crd_exists slurmclusters.slurm.nebius.ai; then
    k -n soperator delete slurmcluster --all --wait=false --ignore-not-found >/dev/null 2>&1 || true
  fi
  strip_ns soperator slurmclusters.slurm.nebius.ai
  strip_ns soperator nodesets.slurm.nebius.ai
  strip_ns soperator activechecks.slurm.nebius.ai
  strip_ns soperator apparmorprofiles.security-profiles-operator.x-k8s.io
fi

# 3. Admission webhooks
k delete mutatingwebhookconfiguration,validatingwebhookconfiguration \
  -l app.kubernetes.io/name=kruise --ignore-not-found --wait=false >/dev/null 2>&1 || true
while read -r obj; do
  [[ -z "${obj}" ]] && continue
  k delete "${obj}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
done <<< "${platform_webhooks}"

if ns_exists monitoring-system; then
  strip_ns monitoring-system vmsingles.operator.victoriametrics.com
  strip_ns monitoring-system vmagents.operator.victoriametrics.com
  strip_ns monitoring-system persistentvolumeclaims
  for kind in deploy svc secret sa; do
    strip_ns monitoring-system "${kind}"
  done
fi

# 4. Namespaces
for ns in "${platform_ns[@]}"; do
  echo "Deleting namespace ${ns}"
  k delete ns "${ns}" --wait=false --ignore-not-found >/dev/null 2>&1 || true
done

# 5. Flux CRDs (local only — do not kubectl -f a GitHub URL)
while read -r obj; do
  [[ -z "${obj}" ]] && continue
  k patch "${obj}" --type merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
done < <(k get crd -o name 2>/dev/null | grep toolkit.fluxcd.io || true)

# 6. Wait only if something is actually Terminating.
deadline=$((SECONDS + 60))
while (( SECONDS < deadline )); do
  leftover=0
  for ns in "${NAMESPACES[@]}"; do
    if ns_exists "${ns}"; then
      leftover=1
      break
    fi
  done
  if [[ "${leftover}" -eq 0 ]]; then
    break
  fi
  sleep 2
done

for ns in "${NAMESPACES[@]}"; do
  ns_exists "${ns}" || continue
  echo "Namespace ${ns} still Terminating; stripping remaining finalizers..."
  strip_ns "${ns}" apparmorprofiles.security-profiles-operator.x-k8s.io
  strip_ns "${ns}" helmrelease.helm.toolkit.fluxcd.io
  strip_ns "${ns}" vmsingles.operator.victoriametrics.com
  strip_ns "${ns}" vmagents.operator.victoriametrics.com
  for kind in deploy svc secret sa pvc statefulset daemonset job; do
    strip_ns "${ns}" "${kind}"
  done
done

# 7. Cluster-scoped CRDs
while read -r obj; do
  [[ -z "${obj}" ]] && continue
  k delete "${obj}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
done < <(k get crd -o name 2>/dev/null | grep -iE "${CRD_PATTERN}" || true)

echo "Platform Kubernetes wipe finished."
k get ns
