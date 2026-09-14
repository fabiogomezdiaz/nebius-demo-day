# Task 2 — vLLM serve

| File | Role |
| --- | --- |
| `01-gpu_mode.sh` | Flip GPUs: `serve` (workers=1 + vLLM) or `train` (workers=2) |
| `k8s/vllm.yaml` | Deployment + ClusterIP Service in `soperator` (needs `jail-submount-data-pvc`) |

```bash
./task-2/01-gpu_mode.sh serve
```

Runbook: [../docs/task-2/README.md](../docs/task-2/README.md).
