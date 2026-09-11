#!/usr/bin/env bash
# Tiny retry helper used by terraform/infra/envrc.example.
set -euo pipefail

retries=5
interval=2

while [[ $# -gt 0 && "$1" != "--" ]]; do
  case "$1" in
    -n) retries="$2"; shift 2 ;;
    -i) interval="$2"; shift 2 ;;
    *)
      echo "Usage: retry.sh [-n retries] [-i interval] -- <command>" >&2
      exit 1
      ;;
  esac
done
[[ "${1:-}" == "--" ]] && shift

if [[ $# -eq 0 ]]; then
  echo "Usage: retry.sh [-n retries] [-i interval] -- <command>" >&2
  exit 1
fi

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

for i in $(seq 1 "$retries"); do
  if "$@" 2>"$err"; then
    cat "$err" >&2
    exit 0
  fi
  cat "$err" >&2
  if grep -Eq 'PermissionDenied|Unauthenticated|UNAUTHENTICATED' "$err"; then
    exit 1
  fi
  if [[ $i -lt "$retries" ]]; then
    echo "($i/$retries) Command failed, retrying in ${interval}s..." >&2
    sleep "$interval"
  fi
done

echo "Command failed after $retries attempts" >&2
exit 1
