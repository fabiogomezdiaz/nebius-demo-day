# Task 3 — two vLLM processes (base vs LoRA)

| File | Role |
| --- | --- |
| `common.sh` | kubeconfig + `k` / `apply` (sourced by 01–03) |
| `01-serve.sh` | Pause Flux, workers=0, apply namespace / data / both vLLMs / Ingress |
| `02-status.sh` | Worker pods, GPU allocation (node = dashboard series), Ingress |
| `03-compare.sh` | 10 prompts on two URLs; writes `docs/task-3/compare.md` |
| `fetch_prompts.py` | Rebuild `prompts.jsonl` from Dolly `train[1500:]` |
| `prompts.jsonl` | 100 held-out prompts (`id`, `category`, `content`, `gold`) |
| `k8s/flux-pause.yaml` | Suspend HelmRelease `soperator-fluxcd` |
| `k8s/workers-0.yaml` | NodeSet `worker` replicas=0 |
| `k8s/namespace.yaml` | Namespace `task3-inference` |
| `k8s/data.yaml` | Two RWX claims of jail `/mnt/data` (one per pod) |
| `k8s/vllm.yaml` | `vllm-base` + `vllm-dolly` Deployments and Services |
| `k8s/ingress.yaml` | Host per model, same LoadBalancer as task 2 |

```bash
./task-2/01-ingress.sh     # once; prints the A-record IP
./task-3/01-serve.sh       # workers=0 + both vLLMs
./task-3/02-status.sh
./task-3/03-compare.sh     # 10 prompts → docs/task-3/compare.md
./task-4/01-load.sh        # both GPUs busy (task 4)
./task-1/03-apply_platform.sh   # back to two Slurm workers
```

Add a second DNS A record for the base host (same IP as Dolly):

```text
A  quen-qwen25.fabiogomezdiaz.app      →  <LB IP>
A  quen-lora-dolly.fabiogomezdiaz.app  →  <LB IP>
```

Runbook: [../docs/task-3/README.md](../docs/task-3/README.md).
