#!/usr/bin/env bash
# Cycle 100 held-out Dolly prompts against both vLLMs forever. Ctrl-C stops.
# Needs task 3 serve + DNS: ./task-3/01-serve.sh
# CONCURRENCY=4 MAX_TOKENS=512 to push SM higher.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${BASE_URL:-http://quen-qwen25.fabiogomezdiaz.app}"
DOLLY_URL="${DOLLY_URL:-http://quen-lora-dolly.fabiogomezdiaz.app}"
TOKENS="${MAX_TOKENS:-512}"
N="${CONCURRENCY:-4}"
PROMPTS="${PROMPTS:-${ROOT}/task-3/prompts.jsonl}"

if [[ ! -f "${PROMPTS}" ]]; then
  echo "Missing ${PROMPTS}. Run python3 task-3/fetch_prompts.py" >&2
  exit 1
fi

ROWS=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ -n "${line}" ]] || continue
  ROWS+=("${line}")
done < "${PROMPTS}"
COUNT="${#ROWS[@]}"
if [[ "${COUNT}" -eq 0 ]]; then
  echo "No prompts in ${PROMPTS}" >&2
  exit 1
fi

hit() {
  local url="$1" model="$2" label="$3" idx="$4"
  local row content body code
  while true; do
    row="${ROWS[idx]}"
    content="$(jq -r '.content' <<<"${row}")"
    body="$(jq -n --arg model "${model}" --arg content "${content}" --argjson tokens "${TOKENS}" \
      '{model:$model, messages:[{role:"user", content:$content}], max_tokens:$tokens}')"
    code="$(curl -sS -o /dev/null -w '%{http_code}' \
      -H 'Content-Type: application/json' \
      -d "${body}" \
      "${url}/v1/chat/completions" || true)"
    if [[ "${code}" == "200" ]]; then
      printf '%s' "${label}"
    else
      printf 'x'
    fi
    idx=$(( (idx + 1) % COUNT ))
  done
}

echo "prompts   ${PROMPTS}  n=${COUNT}  (loop forever)"
echo "original  ${BASE_URL}  model=qwen25-7b  (.)  ×${N}"
echo "lora      ${DOLLY_URL}  model=dolly      (+)  ×${N}"
echo "max_tokens=${TOKENS}  Ctrl-C stops"
trap 'kill 0' EXIT
i=1
offset=0
while [[ "${i}" -le "${N}" ]]; do
  hit "${BASE_URL}" qwen25-7b '.' "${offset}" &
  hit "${DOLLY_URL}" dolly '+' "${offset}" &
  offset=$(( (offset + 1) % COUNT ))
  i=$((i + 1))
done
wait
