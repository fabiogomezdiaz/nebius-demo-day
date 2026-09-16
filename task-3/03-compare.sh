#!/usr/bin/env bash
# 10 held-out Dolly prompts against original + LoRA. Writes docs/task-3/compare.md

fset -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

#-----------------------
# Step 1: Set paths and config
#-----------------------
BASE_URL="${BASE_URL:-http://${HOST_BASE}}"
DOLLY_URL="${DOLLY_URL:-http://${HOST_DOLLY}}"
PROMPTS="${ROOT}/task-3/prompts.jsonl"
JSONL="${ROOT}/task-3/out/compare.jsonl"
MD="${ROOT}/docs/task-3/compare.md"
LIMIT="${LIMIT:-10}"          # Number of prompts to use
TOKENS="${MAX_TOKENS:-128}"   # Max tokens per model completion

#-----------------------
# Step 2: Prepare output location
#-----------------------
mkdir -p "$(dirname "${JSONL}")"
: > "${JSONL}"

#-----------------------
# Step 3: Count prompts and report
#-----------------------
total="$(head -n "${LIMIT}" "${PROMPTS}" | wc -l | tr -d ' ')"
echo "${total} prompts"

#-----------------------
# Step 4: Run prompts through both models and collect outputs
#-----------------------
n=0
while IFS= read -r row; do
  n=$((n + 1))
  # Parse prompt fields
  id="$(jq -r '.id' <<<"${row}")"
  content="$(jq -r '.content' <<<"${row}")"
  gold="$(jq -r '.gold // empty' <<<"${row}")"
  category="$(jq -r '.category // empty' <<<"${row}")"
  # Build the payload once
  payload="$(jq -n --arg content "${content}" --argjson tokens "${TOKENS}" \
    '{temperature:0, max_tokens:$tokens, messages:[{role:"user", content:$content}]}')"

  tmp="$(mktemp)"

  #---- Query base model ----
  b_meta="$(curl -sS -o "${tmp}" -w '%{http_code} %{time_total}' \
    -H 'Content-Type: application/json' \
    -d "$(jq -c --arg model qwen25-7b '. + {model:$model}' <<<"${payload}")" \
    "${BASE_URL}/v1/chat/completions")"
  [[ "${b_meta%% *}" == "200" ]] || { echo "HTTP ${b_meta%% *} ${BASE_URL}" >&2; exit 1; }
  base="$(jq -c --arg latency "${b_meta#* }" \
    '{latency_s:($latency|tonumber), tokens:.usage.completion_tokens, text:.choices[0].message.content}' "${tmp}")"

  #---- Query LoRA model ----
  d_meta="$(curl -sS -o "${tmp}" -w '%{http_code} %{time_total}' \
    -H 'Content-Type: application/json' \
    -d "$(jq -c --arg model dolly '. + {model:$model}' <<<"${payload}")" \
    "${DOLLY_URL}/v1/chat/completions")"
  [[ "${d_meta%% *}" == "200" ]] || { echo "HTTP ${d_meta%% *} ${DOLLY_URL}" >&2; exit 1; }
  dolly="$(jq -c --arg latency "${d_meta#* }" \
    '{latency_s:($latency|tonumber), tokens:.usage.completion_tokens, text:.choices[0].message.content}' "${tmp}")"

  rm -f "${tmp}"

  # Store all fields in output jsonl
  jq -n -c --arg id "${id}" --arg prompt "${content}" --arg gold "${gold}" --arg category "${category}" \
    --argjson base "${base}" --argjson dolly "${dolly}" \
    '{id:$id, category:$category, prompt:$prompt, gold:$gold, base:$base, dolly:$dolly}' >> "${JSONL}"

  echo "${n}/${total}"
done < <(head -n "${LIMIT}" "${PROMPTS}")

#-----------------------
# Step 5: Render Markdown summary report
#-----------------------
{
  echo "# Task 3 — original vs LoRA"
  echo
  echo "n=${total}, temperature=0, max_tokens=${TOKENS}. Held-out Dolly \`train[1500:]\`."
  echo

  # Use jq to compute aggregates, summary stats, and output the Markdown table
  jq -s --argjson cap "${TOKENS}" -r '
    # Utility functions
    def avg(f): (map(f) | add) / length;
    def ms: ((. * 1000) | floor) / 1000;
    def clip: gsub("\n"; " ") | if length > 160 then .[:160] + "…" else . end | gsub("\\|"; "\\\\|");

    # Aggregations
    (length) as $n
    | (avg(.base.latency_s) | ms) as $bs
    | (avg(.dolly.latency_s) | ms) as $ds
    | ([.[] | select(.base.latency_s < .dolly.latency_s)] | length) as $bf
    | ([.[] | select(.base.tokens >= $cap)] | length) as $bc
    | ([.[] | select(.dolly.tokens >= $cap)] | length) as $dc

    # Print summary
    | "## TL;DR\n\n"
      + "- Job 73 was 4 SFT steps. Answers stay close; no clear LoRA win.\n"
      + "- Original faster on " + ($bf|tostring) + "/" + ($n|tostring)
      + " (mean " + ($bs|tostring) + "s vs " + ($ds|tostring) + "s).\n"
      + "- Token cap " + ($cap|tostring) + " hit on " + ($bc|tostring) + "/" + ($n|tostring)
      + " original, " + ($dc|tostring) + "/" + ($n|tostring) + " LoRA.\n\n"

    # Print results table
      + (["| # | Id | Orig (s) | LoRA (s) | Orig | LoRA |",
          "| ---: | --- | ---: | ---: | --- | --- |"]
         + [to_entries[] | "| \(.key + 1) | `\(.value.id)` | \(.value.base.latency_s) | \(.value.dolly.latency_s) | \(.value.base.text | clip) | \(.value.dolly.text | clip) |"]
         | join("\n"))
      + "\n"
  ' "${JSONL}"
} > "${MD}"

echo "${MD}"
