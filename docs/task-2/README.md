# Task 2 — inference / serve the trained model

Extra mile. Same MK8s cluster as task 1. **Do not destroy Soperator.**

Assignment: run **inference** on the same Kubernetes cluster, **serving** the trained model. GPU limit is still 2×H100 (1 per node).

## Demo flip

Both H100s are held by Soperator `worker-0` / `worker-1` (`nvidia.com/gpu: 1` each). Scale those **pods** to 1 so one card is free for a vLLM Deployment. The GPU **nodes**, login SSH, jail, and checkpoints stay.

| Mode | Command | GPU 0 | GPU 1 |
| --- | --- | --- | --- |
| Task 1 (train) | `./task-2/01-gpu_mode.sh train` | `worker-0` | `worker-1` |
| Task 2 (serve) | `./task-2/01-gpu_mode.sh serve` | `worker-0` | vLLM |
| Look | `./task-2/01-gpu_mode.sh status` | | |

```bash
./task-2/01-gpu_mode.sh serve    # workers=1, apply task-2/k8s/vllm.yaml
./task-2/01-gpu_mode.sh train    # delete vLLM, workers=2
```

`serve` patches Flux (`terraform-fluxcd-values` + the nodesets HelmRelease) **and** `NodeSet/worker`, then waits until `worker-1` is gone before scheduling vLLM. A bare `kubectl scale` is reverted in ~5 minutes.

A 2-node `sbatch` stays `PD` while you are in serve mode. Switch back to `train` before replaying job 73. Login (`./task-1/05-login.sh`) and `/mnt/data` are unchanged in both modes.

## What vLLM mounts

Adapters from job 73: `/mnt/data/nebius-demo/checkpoints/dolly-lora` on PVC `jail-submount-data-pvc` (RWX, already on the GPU nodes). HF cache is the same volume, so Qwen2.5-7B-Instruct should not re-download.

OpenAI-compatible models:

| `model` | Weights |
| --- | --- |
| `dolly` | Qwen2.5-7B-Instruct + LoRA adapters |
| `qwen25-7b` | base, no adapters |

```bash
kubectl --kubeconfig terraform/kubeconfig -n soperator port-forward svc/vllm 8000:8000

curl -s http://127.0.0.1:8000/v1/models | jq .

curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dolly","messages":[{"role":"user","content":"What is Databricks Dolly?"}],"max_tokens":128}'
```

First `serve` pulls `vllm/vllm-openai:v0.10.2` (~several minutes). Manifest: [../../task-2/k8s/vllm.yaml](../../task-2/k8s/vllm.yaml). Script: [../../task-2/01-gpu_mode.sh](../../task-2/01-gpu_mode.sh).

## What not to do

- Do not `terraform destroy` platform or infra.
- Do not scale the MK8s GPU **node group** to 0 (that deletes the H100 VMs).
- Do not scale workers to 0 unless you drop live `sinfo` on purpose. `replicas: 1` keeps Task 1 showable.

See [../overview/status.md](../overview/status.md). Training path: [../task-1/](../task-1/).
