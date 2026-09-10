#!/usr/bin/env bash
# Port-forward vLLM from login node (and optionally workers) to localhost.
set -euo pipefail

KEY="${1:-}"
LOGIN_HOST="${2:-}"
if [[ -z "${KEY}" || -z "${LOGIN_HOST}" ]]; then
  echo "Usage: $0 <ssh-private-key> <login-host>" >&2
  exit 1
fi

echo "Forwarding localhost:8000 (base) and localhost:8001 (fine-tuned) via ${LOGIN_HOST}"
echo "If serve jobs bound on workers, this assumes they used --proxy in serve scripts via ssh -L on the login node."
ssh -i "${KEY}" -N \
  -L 8000:127.0.0.1:8000 \
  -L 8001:127.0.0.1:8001 \
  "root@${LOGIN_HOST}"
