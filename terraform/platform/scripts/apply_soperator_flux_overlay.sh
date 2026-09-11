#!/usr/bin/env bash
# Patch flux-system/soperator-fluxcd-values before (or as) Flux renders
# child HelmReleases. The slurm module creates this ConfigMap empty and
# ignore_changes it; this overlay is how the lab turns off bootstrap
# checks that otherwise hang terraform apply.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OVERLAY="${ROOT}/soperator_fluxcd_values_overlay.yaml"
NS="flux-system"
CM="soperator-fluxcd-values"
CTX="${K8S_CLUSTER_CONTEXT:-}"

kubectl_ctx() {
  if [[ -n "${CTX}" ]]; then
    kubectl --context "${CTX}" "$@"
  else
    kubectl "$@"
  fi
}

if [[ ! -f "${OVERLAY}" ]]; then
  echo "Missing overlay ${OVERLAY}" >&2
  exit 1
fi

echo "Waiting for ConfigMap ${NS}/${CM}..."
for _ in $(seq 1 90); do
  if kubectl_ctx -n "${NS}" get configmap "${CM}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! kubectl_ctx -n "${NS}" get configmap "${CM}" >/dev/null 2>&1; then
  echo "ConfigMap ${NS}/${CM} was not created in time." >&2
  exit 1
fi

payload="$(python3 - "${OVERLAY}" <<'PY'
import json, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
print(json.dumps({"data": {"values.yaml": text}}))
PY
)"

kubectl_ctx -n "${NS}" patch configmap "${CM}" --type merge -p "${payload}"
echo "Patched ${NS}/${CM} with lab activechecks overlay."
