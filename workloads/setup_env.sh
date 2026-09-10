#!/usr/bin/env bash
# Create a shared Python env on /mnt/data (visible to every Slurm node via the jail submount).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/mnt/data/nebius-demo}"
ENV_DIR="${PREFIX}/venv"

mkdir -p "${PREFIX}/outputs" "${PREFIX}/checkpoints" "${PREFIX}/hf_cache" "${PREFIX}/workloads"

if [[ ! -x "${ENV_DIR}/bin/python" ]]; then
  python3 -m venv "${ENV_DIR}"
fi

# shellcheck disable=SC1091
source "${ENV_DIR}/bin/activate"
python -m pip install --upgrade pip

# Versions are pinned enough to be reproducible, loose enough to resolve on the jail's Python.
python -m pip install \
  "torch==2.6.0" \
  "transformers==4.51.3" \
  "datasets==3.5.0" \
  "accelerate==1.6.0" \
  "peft==0.15.2" \
  "trl==0.16.1" \
  "vllm==0.8.5" \
  "huggingface_hub==0.30.2" \
  "sentencepiece" \
  "protobuf"

echo "Env ready at ${ENV_DIR}"
echo "Activate with: source ${ENV_DIR}/bin/activate"
echo "HF cache: ${PREFIX}/hf_cache"
