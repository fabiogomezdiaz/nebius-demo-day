#!/usr/bin/env bash
# Copy task-1 job files onto the Slurm login node under /mnt/data.
# Does not send laptop caches, and does not --delete anything already
# on the jail (cluster hf_cache/outputs/checkpoints live next to task-1/).
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

echo "Syncing ${ROOT}/task-1/ to root@${LOGIN_HOST}:/mnt/data/nebius-demo/task-1/"
ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "root@${LOGIN_HOST}" "mkdir -p /mnt/data/nebius-demo/task-1"
rsync -az \
  --exclude '00-*.sh' \
  --exclude '01-*.sh' \
  --exclude '02-*.sh' \
  --exclude '03-*.sh' \
  --exclude '04-sync.sh' \
  --exclude '05-*.sh' \
  --exclude '06-*.sh' \
  --exclude '07-*.sh' \
  --exclude 'login_host.sh' \
  --exclude 'retry.sh' \
  --exclude 'README.md' \
  --exclude 'hf_cache/' \
  --exclude 'outputs/' \
  --exclude 'checkpoints/' \
  --exclude 'models/' \
  --exclude '.venv/' \
  --exclude 'venv/' \
  --exclude '__pycache__/' \
  --exclude '.DS_Store' \
  -e "ssh -i ${KEY}" \
  "${ROOT}/task-1/" "root@${LOGIN_HOST}:/mnt/data/nebius-demo/task-1/"
echo "Done. SSH in with: ./task-1/05-login.sh"
echo "Then: bash /mnt/data/nebius-demo/task-1/setup_env.sh"
