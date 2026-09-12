#!/usr/bin/env bash
# Write Terraform inputs into terraform.tfvars (infra, platform, workloads).
# Precedence: env var → Nebius CLI profile → lab defaults.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA="${ROOT}/terraform/infra"
PLATFORM="${ROOT}/terraform/platform"
WORKLOADS="${ROOT}/terraform/workloads"
RETRY="${ROOT}/scripts/retry.sh"
KUBECONFIG_REL="../kubeconfig"

DEFAULT_TENANT="tenant-e00vj0jkxzwvp8q5xe"
DEFAULT_PROJECT="project-e00dqh87pr00x1qed0hwcy"
DEFAULT_REGION="eu-north1"
SSH_PUBKEY_PATH="${SSH_PUBKEY_PATH:-${HOME}/.ssh/id_rsa.pub}"

cli_get() {
  local value
  value="$(nebius config get "$1" 2>/dev/null || true)"
  value="${value//$'\r'/}"
  value="${value%%$'\n'*}"
  printf '%s' "$value"
}

cli_tenant=""
cli_project=""
if command -v nebius >/dev/null 2>&1; then
  cli_tenant="$(cli_get tenant-id)"
  cli_project="$(cli_get parent-id)"
  [[ "${cli_tenant}" == tenant-* ]] || cli_tenant=""
  [[ "${cli_project}" == project-* ]] || cli_project=""
fi

NEBIUS_TENANT_ID="${NEBIUS_TENANT_ID:-${cli_tenant:-${DEFAULT_TENANT}}}"
NEBIUS_PROJECT_ID="${NEBIUS_PROJECT_ID:-${cli_project:-${DEFAULT_PROJECT}}}"
NEBIUS_REGION="${NEBIUS_REGION:-${DEFAULT_REGION}}"

if [[ ! -f "${SSH_PUBKEY_PATH}" && -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
  SSH_PUBKEY_PATH="${HOME}/.ssh/id_ed25519.pub"
fi
if [[ ! -f "${SSH_PUBKEY_PATH}" ]]; then
  echo "Missing SSH public key: ${SSH_PUBKEY_PATH}" >&2
  echo "Set SSH_PUBKEY_PATH to your .pub file." >&2
  exit 1
fi
if [[ ! -s "${SSH_PUBKEY_PATH}" ]]; then
  echo "Empty SSH public key: ${SSH_PUBKEY_PATH}" >&2
  exit 1
fi

if [[ ! -f "${INFRA}/terraform.tfvars" ]]; then
  echo "Missing ${INFRA}/terraform.tfvars" >&2
  exit 1
fi
if [[ ! -f "${PLATFORM}/terraform.tfvars" ]]; then
  echo "Missing ${PLATFORM}/terraform.tfvars" >&2
  exit 1
fi
if [[ ! -x "${RETRY}" ]]; then
  echo "Missing ${RETRY}" >&2
  exit 1
fi

NEBIUS_VPC_SUBNET_ID="$("${RETRY}" -- nebius vpc subnet list \
  --parent-id "${NEBIUS_PROJECT_ID}" \
  --format json \
  | jq -r '.items[0].metadata.id')"
if [[ -z "${NEBIUS_VPC_SUBNET_ID}" || "${NEBIUS_VPC_SUBNET_ID}" == "null" ]]; then
  echo "Could not read the default VPC subnet for ${NEBIUS_PROJECT_ID}" >&2
  exit 1
fi

set_tfvars_string() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"
  if grep -qE "^${key}[[:space:]]*=" "${file}"; then
    awk -v k="${key}" -v v="${value}" '
      $0 ~ "^" k "[[:space:]]*=" { print k " = \"" v "\""; next }
      { print }
    ' "${file}" > "${tmp}"
    mv "${tmp}" "${file}"
  else
    printf '%s = "%s"\n' "${key}" "${value}" >> "${file}"
  fi
}

set_tfvars_string "${INFRA}/terraform.tfvars" region "${NEBIUS_REGION}"
set_tfvars_string "${INFRA}/terraform.tfvars" iam_tenant_id "${NEBIUS_TENANT_ID}"
set_tfvars_string "${INFRA}/terraform.tfvars" iam_project_id "${NEBIUS_PROJECT_ID}"
set_tfvars_string "${INFRA}/terraform.tfvars" vpc_subnet_id "${NEBIUS_VPC_SUBNET_ID}"

tfvars_tmp="$(mktemp)"
awk '
  /^slurm_login_ssh_root_public_keys[[:space:]]*=/ {
    if ($0 ~ /\]/) next
    skip = 1
    next
  }
  skip && /\]/ { skip = 0; next }
  skip { next }
  { print }
' "${PLATFORM}/terraform.tfvars" > "${tfvars_tmp}"
mv "${tfvars_tmp}" "${PLATFORM}/terraform.tfvars"

set_tfvars_string "${PLATFORM}/terraform.tfvars" slurm_login_ssh_root_public_key_path "${SSH_PUBKEY_PATH}"
set_tfvars_string "${PLATFORM}/terraform.tfvars" kubeconfig_path "${KUBECONFIG_REL}"

if [[ -f "${WORKLOADS}/versions.tf" ]]; then
  if [[ ! -f "${WORKLOADS}/terraform.tfvars" ]]; then
    printf 'kubeconfig_path = "%s"\n' "${KUBECONFIG_REL}" > "${WORKLOADS}/terraform.tfvars"
  else
    set_tfvars_string "${WORKLOADS}/terraform.tfvars" kubeconfig_path "${KUBECONFIG_REL}"
  fi
fi

echo "Seeded ${INFRA}/terraform.tfvars"
echo "  region=${NEBIUS_REGION}"
echo "  iam_tenant_id=${NEBIUS_TENANT_ID}"
echo "  iam_project_id=${NEBIUS_PROJECT_ID}"
echo "  vpc_subnet_id=${NEBIUS_VPC_SUBNET_ID}"
echo "Seeded SSH public key path ${SSH_PUBKEY_PATH} into ${PLATFORM}/terraform.tfvars"
echo "Seeded kubeconfig_path=${KUBECONFIG_REL}"
echo
echo "Next: ./scripts/02-apply_infra.sh"
