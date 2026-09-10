#!/usr/bin/env bash
# Shared helpers for vLLM Slurm serve jobs.
set -euo pipefail

PREFIX=/mnt/data/nebius-demo
# shellcheck disable=SC1091
source "${PREFIX}/venv/bin/activate"

export HF_HOME="${PREFIX}/hf_cache"
export TRANSFORMERS_CACHE="${PREFIX}/hf_cache"
export CUDA_VISIBLE_DEVICES=0

# vLLM still initializes distributed backends; keep them on Ethernet.
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME="${NCCL_SOCKET_IFNAME:-eth0}"

HOST="$(hostname -I | awk '{print $1}')"
PORT="${PORT:?PORT is required}"
MODEL="${MODEL:?MODEL is required}"
HOSTFILE="${HOSTFILE:?HOSTFILE is required}"

echo "${HOST}:${PORT}" > "${HOSTFILE}"
echo "Serving ${MODEL} on ${HOST}:${PORT}"

# From the login node, users SSH-tunnel via the worker IP recorded in HOSTFILE.
# Also listen on all interfaces so compare.py can use the cluster network.
exec python -m vllm.entrypoints.openai.api_server \
  --model "${MODEL}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --dtype bfloat16 \
  --max-model-len "${MAX_MODEL_LEN:-2048}" \
  --gpu-memory-utilization "${GPU_UTIL:-0.90}" \
  ${LORA_ARGS:-}
