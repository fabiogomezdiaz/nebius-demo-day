#!/usr/bin/env bash
# SSH to the Slurm login node (sshd in the login pod, via LoadBalancer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY="${1:-${SSH_PRIVATE_KEY:-${HOME}/.ssh/id_rsa}}"
LOGIN_HOST="${2:-}"
USER="${SSH_USER:-root}"

if [[ ! -f "${KEY}" ]]; then
  echo "Missing SSH private key: ${KEY}" >&2
  echo "Usage: $0 [ssh-private-key] [login-host]" >&2
  echo "Default key is ~/.ssh/id_rsa (or SSH_PRIVATE_KEY). Login host is read from soperator-login-svc if omitted." >&2
  exit 1
fi

if [[ -z "${LOGIN_HOST}" ]]; then
  LOGIN_HOST="$("${ROOT}/scripts/login_host.sh")"
fi

exec ssh -i "${KEY}" -o StrictHostKeyChecking=accept-new "${USER}@${LOGIN_HOST}"
