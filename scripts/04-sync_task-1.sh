#!/usr/bin/env bash
# Copy workloads/ onto the Slurm login node under /mnt/data.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${1:-${SSH_PRIVATE_KEY:-${HOME}/.ssh/id_rsa}}"
LOGIN_HOST="${2:-}"

if [[ ! -f "${KEY}" ]]; then
  echo "Missing SSH private key: ${KEY}" >&2
  echo "Usage: $0 [ssh-private-key] [login-host]" >&2
  echo "Default key is ~/.ssh/id_rsa (or SSH_PRIVATE_KEY). Login host is read from soperator-login-svc if omitted." >&2
  exit 1
fi

if [[ -z "${LOGIN_HOST}" ]]; then
  LOGIN_HOST="$("${ROOT}/scripts/login_host.sh")"
fi

echo "Syncing workloads to root@${LOGIN_HOST}:/mnt/data/nebius-demo"
ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "root@${LOGIN_HOST}" "mkdir -p /mnt/data/nebius-demo"
rsync -az -e "ssh -i ${KEY}" \
  "${ROOT}/workloads/" "root@${LOGIN_HOST}:/mnt/data/nebius-demo/workloads/"
echo "Done. SSH in with: ./scripts/05-login.sh"
echo "Then: bash /mnt/data/nebius-demo/workloads/setup_env.sh"
