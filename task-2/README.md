# Task 2 — vLLM serve

| File | Role |
| --- | --- |
| `common.sh` | kubeconfig + `k` / `apply` (sourced by 01–04) |
| `01-ingress.sh` | Install ingress-nginx LoadBalancer in `task2-ingress` (once) |
| `02-serve.sh` | Pause Flux, workers=1, apply namespace / data / vLLM / Ingress (drops task 3 if present) |
| `03-status.sh` | Worker pods, GPU allocation, vLLM, Ingress |
| `04-destroy_ingress.sh` | Remove controller (vLLM/Soperator stay) |
| `05-load.sh` | Sequential chat completions at the public hostname (raise GPU util) |
| `k8s/flux-pause.yaml` | Suspend HelmRelease `soperator-fluxcd` so it does not reset workers |
| `k8s/flux-resume.yaml` | Unsuspend Flux (used by `task-1/03-apply_platform.sh`) |
| `k8s/workers-1.yaml` | NodeSet `worker` replicas=1 |
| `k8s/workers-2.yaml` | NodeSet `worker` replicas=2 (used by `task-1/03-apply_platform.sh`) |
| `k8s/namespace.yaml` | Namespace `task2-inference` |
| `k8s/data.yaml` | Second RWX claim of jail `/mnt/data` (adapters + HF cache) |
| `k8s/vllm.yaml` | Deployment + ClusterIP Service in `task2-inference` |
| `k8s/ingress.yaml` | Host `quen-lora-dolly.fabiogomezdiaz.app` → `svc/vllm` |
| `k8s/ingress-nginx-values.yaml` | Helm values for the LoadBalancer |

```bash
./task-2/01-ingress.sh    # prints the A-record IP; DNS is yours
./task-2/02-serve.sh      # workers=1 + all task-2 k8s artifacts
./task-2/03-status.sh
./task-2/05-load.sh          # optional: keep the GPU busy (Ctrl-C)
./task-1/03-apply_platform.sh   # back to two Slurm workers
```

Runbook: [../docs/task-2/README.md](../docs/task-2/README.md). Talk track: [../docs/task-2/report.md](../docs/task-2/report.md).
