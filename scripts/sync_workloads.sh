#!/usr/bin/env bash
# Copy workloads/ and docs snippets onto the Slurm login node under /mnt/data.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${1:-}"
LOGIN_HOST="${2:-}"

if [[ -z "${KEY}" ]]; then
  echo "Usage: $0 <ssh-private-key> [login-host]" >&2
  echo "If login-host is omitted, it is read from vendor/.../installations/demo-day via terraform state." >&2
  exit 1
fi

if [[ -z "${LOGIN_HOST}" ]]; then
  INSTALL_DIR="${ROOT}/vendor/nebius-solutions-library/soperator/installations/demo-day"
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    echo "No installation dir at ${INSTALL_DIR}. Pass the login host explicitly." >&2
    exit 1
  fi
  LOGIN_HOST="$(
    terraform -chdir="${INSTALL_DIR}" state show module.login_script.terraform_data.lb_service_ip 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
      | head -n 1 || true
  )"
  if [[ -z "${LOGIN_HOST}" && -x "${INSTALL_DIR}/login.sh" ]]; then
    echo "Could not parse login IP from terraform state. Pass it as argument 2." >&2
    echo "Hint: cd ${INSTALL_DIR} && ./login.sh -k ${KEY}" >&2
    exit 1
  fi
fi

echo "Syncing workloads to root@${LOGIN_HOST}:/mnt/data/nebius-demo"
ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "root@${LOGIN_HOST}" "mkdir -p /mnt/data/nebius-demo"
rsync -az -e "ssh -i ${KEY}" \
  "${ROOT}/workloads/" "root@${LOGIN_HOST}:/mnt/data/nebius-demo/workloads/"
echo "Done. SSH in and run: bash /mnt/data/nebius-demo/workloads/setup_env.sh"
