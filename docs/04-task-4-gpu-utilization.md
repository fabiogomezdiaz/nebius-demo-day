# GPU utilization

Show both H100s above **80% SM utilization** in Nebius console dashboards (and `nvidia-smi` / DCGM).

Capacity is two GPUs. “More than 80% of the GPUs” means both cards busy, not 80% of a larger pool. Utilization **on each GPU** should also exceed 80% so the dashboard is clearly loaded.

## When GPUs are busy

| Phase | GPUs used | How they stay hot |
| --- | --- | --- |
| Training | 2/2 | DDP LoRA with sequence length 2048 and a large per-device batch |
| Dual serving + load | 2/2 | Base on GPU 0, fine-tuned on GPU 1, `loadgen.py` against both |

A 7B LoRA with a tiny batch will not saturate an H100. The batch script prefers a large token batch (`PER_DEVICE_BATCH` × `SEQ_LEN` × `GRAD_ACCUM`).

## During training

1. Nebius console → compute / MK8s monitoring → GPU utilization.
2. On a worker: `srun -w worker-0 nvidia-smi dmon -s u`.
3. Capture while `gpu-util` is ≥ 80 on both nodes.
4. If utilization is low: increase `PER_DEVICE_BATCH` or `SEQ_LEN` in `train.sbatch` and resubmit. Decrease only on OOM.

## During inference

Keep both serve jobs running. From the login node:

```bash
python /mnt/data/nebius-demo/workloads/loadgen.py --seconds 180
```

Concurrent chat completions against both endpoints fill vLLM’s continuous batching.

## Design note

Two H100s, one per node, no cross-node NVLink domain and no InfiniBand. Training uses both via DDP over Ethernet. After training, one GPU serves the base model and one serves the fine-tuned model so the comparison is live and both cards stay utilized.
