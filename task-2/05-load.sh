#!/usr/bin/env bash
# Keep the served model busy so GPU SM util is not 0% while parked.
# Needs serve + DNS: ./task-2/02-serve.sh
# Ctrl-C stops. MODEL=dolly MAX_TOKENS=256
set -euo pipefail

URL="${VLLM_URL:-http://quen-lora-dolly.fabiogomezdiaz.app}"
MODEL="${MODEL:-dolly}"
TOKENS="${MAX_TOKENS:-256}"

body="{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Explain Databricks Dolly, instruction tuning, and LoRA in detail with examples.\"}],\"max_tokens\":${TOKENS}}"

echo "Load POST ${URL}/v1/chat/completions  model=${MODEL}  max_tokens=${TOKENS}"

while true; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    -d "${body}" \
    "${URL}/v1/chat/completions" || true)"
  if [[ "${code}" == "200" ]]; then
    printf '.'
  else
    printf 'x'
  fi
done
