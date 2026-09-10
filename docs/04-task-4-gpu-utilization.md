# Task 4 — Use more than 80% of the GPUs

## Goal

Show both H100s above **80% SM utilization** in Nebius console dashboards (and `nvidia-smi` / DCGM).

Capacity: 2 GPUs total. "More than 80% of the GPUs" means both cards busy, not 80% of a larger pool. Also push **utilization of each GPU** above 80% so the dashboard looks obviously green.

## When GPUs are busy

| Phase | GPUs used | How we keep them hot |
| --- | --- | --- |
| Training | 2/2 | DDP LoRA with seq length 2048 and a large per-device batch |
| Dual serving + load | 2/2 | Base on GPU 0, fine-tuned on GPU 1, `loadgen.py` hammers both |

A 7B LoRA with a tiny batch will *not* saturate an H100. The batch script therefore prefers a large token batch (`PER_DEVICE_BATCH` × `SEQ_LEN` × `GRAD_ACCUM`).

## Steps

### During training

1. Open Nebius console → compute / MK8s monitoring → GPU utilization.
2. On a worker: `srun -w worker-0 nvidia-smi dmon -s u`.
3. Screenshot while `gpu-util` is ≥ 80 on both nodes.
4. If it is low: increase `PER_DEVICE_BATCH` or `SEQ_LEN` in `train.sbatch` and resubmit. Decrease only if you OOM.

### During inference (backup way to show 2/2 GPUs)

1. Keep both serve jobs running.
2. From the login node:

```bash
python /mnt/data/nebius-demo/workloads/loadgen.py --seconds 180
```

This fires concurrent chat completions at both endpoints so vLLM's continuous batching fills the GPUs.

## Talking point

"We only have two H100s, one per node, no NVLink domain across nodes and no InfiniBand. Training uses both via DDP over Ethernet. After training, we pin one GPU to the base server and one to the fine-tuned server so the comparison is live and both cards stay utilized."
