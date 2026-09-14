#!/usr/bin/env bash
# Copy task-1/ onto the Slurm login node under /mnt/data.
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
  LOGIN_HOST="$("${ROOT}/task-1/login_host.sh")"
fi

echo "Syncing task-1 to root@${LOGIN_HOST}:/mnt/data/nebius-demo"
ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "root@${LOGIN_HOST}" "mkdir -p /mnt/data/nebius-demo"
rsync -az --exclude '00-*.sh' --exclude '01-*.sh' --exclude '02-*.sh' --exclude '03-*.sh' --exclude '04-sync.sh' --exclude '05-*.sh' --exclude '06-*.sh' --exclude '07-*.sh' --exclude 'login_host.sh' --exclude 'retry.sh' --exclude 'README.md' -e "ssh -i ${KEY}" \
  "${ROOT}/task-1/" "root@${LOGIN_HOST}:/mnt/data/nebius-demo/task-1/"
echo "Done. SSH in with: ./task-1/05-login.sh"
echo "Then: bash /mnt/data/nebius-demo/task-1/setup_env.sh"
