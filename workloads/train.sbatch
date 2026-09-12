#!/bin/bash
#SBATCH --job-name=helios-lora
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=80G
#SBATCH --time=02:00:00
#SBATCH --output=/mnt/data/nebius-demo/outputs/train-%j.log
#SBATCH --error=/mnt/data/nebius-demo/outputs/train-%j.err

set -euo pipefail

PREFIX=/mnt/data/nebius-demo
source "${PREFIX}/venv/bin/activate"

export HF_HOME="${PREFIX}/hf_cache"
export TRANSFORMERS_CACHE="${PREFIX}/hf_cache"
export TOKENIZERS_PARALLELISM=false

# Ethernet-only NCCL. 1xH100 nodes have no InfiniBand fabric.
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_SOCKET_IFNAME="eth0"
export GLOO_SOCKET_IFNAME="eth0"
export NCCL_DEBUG=INFO
export TORCH_NCCL_ASYNC_ERROR_HANDLING=1

export BASE_MODEL="Qwen/Qwen2.5-7B-Instruct"
export TRAIN_DATA="${PREFIX}/workloads/data/helios_faq.jsonl"
export OUTPUT_DIR="${PREFIX}/checkpoints/helios-lora"
export SEQ_LEN="2048"
export PER_DEVICE_BATCH="4"
export GRAD_ACCUM="4"
export EPOCHS="8"

nodes=( $(scontrol show hostnames "$SLURM_JOB_NODELIST") )
head_node="${nodes[0]}"
# hostname -I can return docker0 (172.17.0.1) first. Bind rendezvous to eth0.
head_ip=$(srun --nodes=1 --ntasks=1 -w "${head_node}" \
  bash -c 'ip -4 -o addr show dev eth0 | awk "{print \$4}" | cut -d/ -f1')

echo "nodes=${nodes[*]}"
echo "rdzv=${head_ip}:29500"
echo "NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME}"

srun torchrun \
  --nnodes="${SLURM_NNODES}" \
  --nproc_per_node=1 \
  --rdzv_id="${SLURM_JOB_ID}" \
  --rdzv_backend=c10d \
  --rdzv_endpoint="${head_ip}:29500" \
  "${PREFIX}/workloads/train.py"
