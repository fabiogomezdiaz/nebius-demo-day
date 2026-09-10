#!/bin/bash
#SBATCH --job-name=vllm-base
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --time=12:00:00
#SBATCH --output=/mnt/data/nebius-demo/outputs/serve-base-%j.log
#SBATCH --error=/mnt/data/nebius-demo/outputs/serve-base-%j.err

set -euo pipefail
PREFIX=/mnt/data/nebius-demo
export PORT=8000
export MODEL="${BASE_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
export HOSTFILE="${PREFIX}/outputs/serve-base.host"
export LORA_ARGS=""
export GPU_UTIL="${GPU_UTIL:-0.90}"
bash "${PREFIX}/workloads/serve_common.sh"
