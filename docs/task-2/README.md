# Task 2 — inference / serve the trained model

**Not done.** Extra mile.

Assignment: run **inference** on the same Kubernetes cluster, **serving** the trained model. GPU limit is still 2×H100 (1 per node).

## Blocker

Soperator worker pods already bind both GPUs (`nvidia.com/gpu`). A Kubernetes GPU Deployment (vLLM/TGI) stays `Pending`. Serving has to be a **Slurm job** (or workers scaled down — do not do that during the demo).

Checkpoint from task 1: `/mnt/data/nebius-demo/checkpoints/dolly-lora`.

See [../overview/status.md](../overview/status.md). Training path: [../task-1/](../task-1/).
