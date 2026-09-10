# Task 2 — Inference on the same cluster

## Goal

Serve the **fine-tuned** model from a Slurm job on the same MK8s / Soperator cluster that trained it. Use vLLM, which you already know; the only difference is *how the GPU is obtained*.

## Why a Slurm job, not a Deployment

Soperator worker pods already consume `nvidia.com/gpu` on the two H100 nodes. A vLLM Deployment will sit `Pending`. A Slurm allocation *is* the supported way to run serving on this cluster, and it still counts as "inference on the same k8s cluster".

## Steps

### 1. Confirm the adapter exists

On the login node:

```bash
ls /mnt/data/nebius-demo/checkpoints/helios-lora
```

You should see Hugging Face adapter files (`adapter_config.json`, `adapter_model.safetensors`).

### 2. Start vLLM for the fine-tuned model

```bash
sbatch workloads/serve_ft.sbatch
squeue
```

The job:

- Requests **1 node / 1 GPU**
- Runs vLLM with `--enable-lora` and `--lora-modules helios=/mnt/data/nebius-demo/checkpoints/helios-lora`
- Listens on port **8001** on the worker; the batch script also prints the worker hostname

### 3. Open a tunnel from your laptop

```bash
# login node public IP comes from terraform output / login.sh
ssh -i ~/.ssh/<your-private-key> -L 8001:127.0.0.1:8001 root@<login-ip>
```

If vLLM is bound on the worker, not the login node, tunnel hop through the worker from the login node (the serve script writes `/mnt/data/nebius-demo/outputs/serve-ft.host` with `host:port`).

Helper:

```bash
./scripts/tunnel_inference.sh ~/.ssh/<your-private-key>
```

### 4. Smoke test

```bash
curl http://127.0.0.1:8001/v1/models

curl http://127.0.0.1:8001/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "helios",
    "messages": [{"role": "user", "content": "Who is the CEO of Helios Robotics?"}],
    "max_tokens": 128
  }'
```

Expected: an answer that mentions **Mira Chen** (from the training FAQ). The base model will not know that.

## How to explain vLLM here

Same engine you have used on Kubernetes:

- PagedAttention + continuous batching
- OpenAI-compatible `/v1/chat/completions`
- One GPU, tensor parallel size 1 (we only have one GPU per node)

LoRA serving: vLLM loads the base Qwen weights once, then applies the Helios adapter as a named LoRA module. That keeps the checkpoint small and makes A/B serving (task 3) cheap.

## Keep it running

Do not `scancel` the serve job before the comparison and the demo recording. Training should be finished first so both GPUs are free: one GPU for base, one GPU for fine-tuned.
