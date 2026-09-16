# Task 3 — base vs trained compare

Extra mile. **Do not destroy Soperator.**

Assignment: run the **original (untrained)** model and **compare** the results of both models.

Nebius GPU dashboards are **per VM**, not per model name. One vLLM serving both names (task 2) is a single yellow series. Task 3 pins each model to its **own H100** so green vs yellow is the legend.

| Mode | Command | GPU 0 | GPU 1 |
| --- | --- | --- | --- |
| Task 1 (train) | `./task-1/03-apply_platform.sh` | `worker-0` | `worker-1` |
| Task 2 (one process) | `./task-2/02-serve.sh` | `worker-0` | vLLM (both names) |
| Task 3 (two processes) | `./task-3/01-serve.sh` | vLLM base | vLLM LoRA |

```bash
./task-2/01-ingress.sh     # LoadBalancer IP for DNS (once)
./task-3/01-serve.sh       # workers=0, two Deployments, Ingress
./task-3/03-compare.sh     # 10 prompts → docs/task-3/compare.md
./task-4/01-load.sh        # both cards generating (task 4)
./task-1/03-apply_platform.sh  # delete both vLLMs, workers=2
```

`serve` deletes task-2 vLLM (it holds one GPU), pauses Flux, sets NodeSet **replicas=0**, waits until `worker-0` and `worker-1` are gone, then schedules `vllm-base` and `vllm-dolly` with pod anti-affinity. A live `sinfo` has **no GPU nodes** in this mode. Flux would otherwise reset workers from `terraform-fluxcd-values` in ~5 minutes.

vLLM runs in namespace **`task3-inference`**. Each pod has its own PV/PVC on `/mnt/jail-submount-data` (same filestore as job 73). HF cache and adapters are shared on disk, not in one process.

| Host | Service | `model` | Weights |
| --- | --- | --- | --- |
| `quen-qwen25.fabiogomezdiaz.app` | `vllm-base` | `qwen25-7b` | Qwen2.5-7B-Instruct, no adapters |
| `quen-lora-dolly.fabiogomezdiaz.app` | `vllm-dolly` | `dolly` | same base + job 73 LoRA |

Both A records point at the task-2 ingress-nginx LoadBalancer IP. The Dolly record already exists; add the base record before public curls. Without DNS:

```bash
kubectl --kubeconfig terraform/kubeconfig -n task3-inference port-forward svc/vllm-base 8000:8000
kubectl --kubeconfig terraform/kubeconfig -n task3-inference port-forward svc/vllm-dolly 8001:8000

BASE_URL=http://127.0.0.1:8000 DOLLY_URL=http://127.0.0.1:8001 ./task-3/03-compare.sh
```

`03-compare.sh` runs **10 held-out** Dolly rows against two URLs and writes [compare.md](compare.md) (TL;DR + one table). `LIMIT=` to change n. Rebuild prompts with `python3 task-3/fetch_prompts.py`. Job 73 was 4 steps / ~35 s — the quality delta can be small. GPU SM load is [../task-4/](../task-4/).

`./task-3/02-status.sh` prints `node=` for each GPU pod. That hostname is the Nebius instance behind the green/yellow series.

## What not to do

- Do not `terraform destroy` platform or infra.
- Do not scale the MK8s GPU **node group** to 0 (that deletes the H100 VMs).
- Do not expect live `sinfo` / a 2-node `sbatch` while workers=0. Flip back with `./task-1/03-apply_platform.sh` first.

See [../overview/status.md](../overview/status.md). Task 2 (one process): [../task-2/](../task-2/).
