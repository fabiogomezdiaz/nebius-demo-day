# Task 2 — inference / serve the trained model

**Done.** Same MK8s cluster as task 1. vLLM in namespace `task2-inference` on one H100; the other stays a Slurm worker.

Talk track: [report.md](report.md) (curl 200 + `nvidia-smi` + GPU dashboards).

Extra mile. **Do not destroy Soperator.**

Assignment: run **inference** on the same Kubernetes cluster, **serving** the trained model. GPU limit is still 2×H100 (1 per node).

## Demo flip

Both H100s are held by Soperator `worker-0` / `worker-1` (`nvidia.com/gpu: 1` each). Scale those **pods** to 1 so one card is free for a vLLM Deployment. The GPU **nodes**, login SSH, jail, and checkpoints stay.

| Mode | Command | GPU 0 | GPU 1 |
| --- | --- | --- | --- |
| Task 1 (train) | `./task-1/03-apply_platform.sh` | `worker-0` | `worker-1` |
| Task 2 (serve) | `./task-2/02-serve.sh` | `worker-0` | vLLM |
| Look | `./task-2/03-status.sh` | | |

```bash
./task-2/01-ingress.sh     # LoadBalancer IP for DNS (once)
./task-2/02-serve.sh       # workers=1, apply namespace + data + vLLM + Ingress
./task-1/03-apply_platform.sh  # delete vLLM + Ingress, workers=2
./task-2/03-status.sh
```

`serve` applies `k8s/flux-pause.yaml` (suspend HelmRelease `soperator-fluxcd`) then `k8s/workers-1.yaml` (NodeSet replicas=1), and waits until `worker-1` is gone before scheduling vLLM. Flux would otherwise reset workers from `terraform-fluxcd-values` in ~5 minutes. Re-running `./task-1/03-apply_platform.sh` deletes vLLM, applies `k8s/flux-resume.yaml` + `k8s/workers-2.yaml`, and waits for both workers.

vLLM runs in namespace **`task2-inference`**, not `soperator`. Slurm workers, login, and the original jail PVC stay in `soperator`. `./task-1/03-apply_platform.sh` deletes the vLLM Deployment/Service **and** the Ingress, then returns both GPUs to Slurm; the inference namespace, `/mnt/data` claim, and ingress-nginx controller stay so the next `serve` is a flip, not a rebuild.

A 2-node `sbatch` stays `PD` while you are in serve mode. Re-run `./task-1/03-apply_platform.sh` before replaying job 73. Login (`./task-1/05-login.sh`) and `/mnt/data` are unchanged in both modes.

## What vLLM mounts

Adapters from job 73: `/mnt/data/nebius-demo/checkpoints/dolly-lora`. That path is the jail submount (`/mnt/jail-submount-data` on GPU nodes). Kubernetes binds one PVC per PV, so Task 2 does **not** reuse `soperator/jail-submount-data-pvc`. `k8s/data.yaml` adds PV `jail-submount-data-task2-pv` (same local path, `Retain`) and PVC `task2-inference/jail-submount-data`. HF cache is on that volume, so Qwen2.5-7B-Instruct should not re-download.

Anti-affinity must name namespace `soperator`: without `namespaces: [soperator]`, a pod in `task2-inference` would ignore `worker-0` and could land on the same H100.

OpenAI-compatible models:

| `model` | Weights |
| --- | --- |
| `dolly` | Qwen2.5-7B-Instruct + LoRA adapters |
| `qwen25-7b` | base, no adapters |

```bash
kubectl --kubeconfig terraform/kubeconfig -n task2-inference port-forward svc/vllm 8000:8000

curl -s http://127.0.0.1:8000/v1/models | jq .

curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"dolly","messages":[{"role":"user","content":"What is Databricks Dolly?"}],"max_tokens":128}'
```

First `./task-2/02-serve.sh` pulls `vllm/vllm-openai:v0.10.2` (~several minutes). Manifest: [../../task-2/k8s/vllm.yaml](../../task-2/k8s/vllm.yaml). Script: [../../task-2/02-serve.sh](../../task-2/02-serve.sh).

A Service named `vllm` makes Kubernetes inject `VLLM_PORT=tcp://<clusterIP>:8000`. vLLM reads that as its listen port and the engine dies at startup. The Deployment sets `enableServiceLinks: false` so those Docker-style service env vars are not injected.

## Ingress (optional public hostname)

No Ingress controller ships with this MK8s cluster. Install **ingress-nginx** once in namespace `task2-ingress` (Helm values: [../../task-2/k8s/ingress-nginx-values.yaml](../../task-2/k8s/ingress-nginx-values.yaml)):

```bash
./task-2/01-ingress.sh
```

That prints a LoadBalancer IP. Point DNS yourself:

```text
A  quen-lora-dolly.fabiogomezdiaz.app  →  <printed IP>
```

`./task-2/02-serve.sh` applies the Ingress object with the other task-2 manifests. Then:

```bash
curl -s http://quen-lora-dolly.fabiogomezdiaz.app/v1/models | jq .
```

To keep the H100 busy (idle serve is ~0% SM):

```bash
./task-2/05-load.sh
```

HTTP only (no TLS). `./task-1/03-apply_platform.sh` deletes the Ingress (controller stays). Tear down the LB with `./task-2/04-destroy_ingress.sh`.

## What not to do

- Do not `terraform destroy` platform or infra.
- Do not scale the MK8s GPU **node group** to 0 (that deletes the H100 VMs).
- Do not scale workers to 0 unless you drop live `sinfo` on purpose. `replicas: 1` keeps Task 1 showable.

See [../overview/status.md](../overview/status.md). Training path: [../task-1/](../task-1/).
