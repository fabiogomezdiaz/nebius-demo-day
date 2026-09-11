# Inference on the same cluster

Serve the **fine-tuned** model from a Slurm job on the same MK8s / Soperator cluster that trained it. The serving engine is vLLM; the GPU is obtained through Slurm, not a Kubernetes Deployment.

## Why a Slurm job

Soperator worker pods already consume `nvidia.com/gpu` on the two H100 nodes. A vLLM Deployment stays `Pending`. A Slurm allocation is the supported way to run serving here, and it is still inference on the same Kubernetes cluster.

## Confirm the adapter

On the login node:

```bash
ls /mnt/data/nebius-demo/checkpoints/helios-lora
```

Expected Hugging Face adapter files: `adapter_config.json`, `adapter_model.safetensors`.

## Start vLLM for the fine-tuned model

```bash
sbatch workloads/serve_ft.sbatch
squeue
```

The job:

- Requests **1 node / 1 GPU**
- Runs vLLM with `--enable-lora` and `--lora-modules helios=/mnt/data/nebius-demo/checkpoints/helios-lora`
- Listens on port **8001** on the worker; the batch script prints the worker hostname

## Tunnel from the operator workstation

```bash
# login node public IP from terraform/workloads/login.sh
ssh -i <ssh-private-key> -L 8001:127.0.0.1:8001 root@<login-ip>
```

If vLLM is bound on the worker, hop through the worker from the login node. The serve script writes `/mnt/data/nebius-demo/outputs/serve-ft.host` as `host:port`.

Helper:

```bash
./scripts/06-tunnel_inference.sh <ssh-private-key> <login-host>
```

## Smoke test

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

Expected: an answer that mentions **Mira Chen** (training FAQ). The base model does not know that fact.

## vLLM in this layout

- PagedAttention and continuous batching
- OpenAI-compatible `/v1/chat/completions`
- One GPU, tensor parallel size 1 (one GPU per node)

LoRA serving: vLLM loads base Qwen weights once, then applies the Helios adapter as a named LoRA module. The checkpoint stays small; A/B serving (base vs fine-tuned) is inexpensive.

Leave the serve job running through comparison and the live walkthrough. Finish training first so both GPUs are free: one for base, one for fine-tuned.
