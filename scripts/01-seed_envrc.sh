#!/usr/bin/env bash
# Write tenant/project into terraform/infra/.envrc and the SSH public key
# into terraform.tfvars. Copies envrc.example when .envrc is missing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ROOT}/terraform/infra"
PLATFORM="${ROOT}/terraform/platform"
WORKLOADS="${ROOT}/terraform/workloads"

# Precedence: env var → Nebius CLI profile → lab defaults.
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
SSH_PUBKEY="$(tr -d '\r\n' < "${SSH_PUBKEY_PATH}")"
if [[ -z "${SSH_PUBKEY}" ]]; then
  echo "Empty SSH public key: ${SSH_PUBKEY_PATH}" >&2
  exit 1
fi

if [[ ! -f "${DEST}/terraform.tfvars" ]]; then
  echo "Missing overlay tfvars: ${DEST}/terraform.tfvars" >&2
  exit 1
fi

for dir in "${DEST}" "${PLATFORM}" "${WORKLOADS}"; do
  if [[ ! -f "${dir}/.envrc" ]]; then
    cp "${dir}/envrc.example" "${dir}/.envrc"
    echo "Wrote ${dir}/.envrc from envrc.example"
  fi
done

set_assignment() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v k="${key}" -v v="${value}" '
    $0 ~ "^" k "=" { print k "=\"" v "\""; next }
    { print }
  ' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

set_assignment "${DEST}/.envrc" NEBIUS_TENANT_ID "${NEBIUS_TENANT_ID}"
set_assignment "${DEST}/.envrc" NEBIUS_PROJECT_ID "${NEBIUS_PROJECT_ID}"
set_assignment "${DEST}/.envrc" NEBIUS_REGION "${NEBIUS_REGION}"

tfvars_tmp="$(mktemp)"
awk -v pubkey="${SSH_PUBKEY}" '
  /^slurm_login_ssh_root_public_keys/ {
    print "slurm_login_ssh_root_public_keys = ["
    print "  \"" pubkey "\","
    print "]"
    skip = 1
    next
  }
  skip && /^\]/ { skip = 0; next }
  skip { next }
  { print }
' "${DEST}/terraform.tfvars" > "${tfvars_tmp}"
mv "${tfvars_tmp}" "${DEST}/terraform.tfvars"

echo "Seeded ${DEST}/.envrc"
echo "  NEBIUS_TENANT_ID=${NEBIUS_TENANT_ID}"
echo "  NEBIUS_PROJECT_ID=${NEBIUS_PROJECT_ID}"
echo "  NEBIUS_REGION=${NEBIUS_REGION}"
echo "Seeded SSH public key from ${SSH_PUBKEY_PATH} into ${DEST}/terraform.tfvars"
echo
echo "Next: ./scripts/02-apply_infra.sh"
