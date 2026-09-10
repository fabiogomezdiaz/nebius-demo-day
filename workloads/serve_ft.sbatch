#!/bin/bash
#SBATCH --job-name=vllm-helios
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --time=12:00:00
#SBATCH --output=/mnt/data/nebius-demo/outputs/serve-ft-%j.log
#SBATCH --error=/mnt/data/nebius-demo/outputs/serve-ft-%j.err

set -euo pipefail
PREFIX=/mnt/data/nebius-demo
ADAPTER="${PREFIX}/checkpoints/helios-lora"
export PORT=8001
export MODEL="${BASE_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
export HOSTFILE="${PREFIX}/outputs/serve-ft.host"
export GPU_UTIL="${GPU_UTIL:-0.90}"
export LORA_ARGS="--enable-lora --lora-modules helios=${ADAPTER} --max-loras 1 --max-cpu-loras 1"
bash "${PREFIX}/workloads/serve_common.sh"
