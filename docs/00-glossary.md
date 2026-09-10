# Glossary (vLLM / GPU Operator → Soperator)

You already know two pieces of the NVIDIA-on-Kubernetes stack:

- **NVIDIA GPU Operator** discovers GPUs, installs drivers, and advertises `nvidia.com/gpu` so pods can request GPUs.
- **vLLM** loads a model onto those GPUs and serves an OpenAI-compatible HTTP API.

Soperator sits *next to* that world, not instead of Kubernetes. It is a Kubernetes operator that turns a `SlurmCluster` custom resource into a working **Slurm** cluster (login node, controller, GPU workers, shared storage). You still have an MK8s cluster. You just submit training and serving as **Slurm jobs** instead of raw Deployments.

## Map of concepts

| You know this | In this assignment it is |
| --- | --- |
| `kubectl apply` a GPU Deployment | `sbatch` a job; Slurm places it on worker pods |
| GPU Operator / device plugin | Soperator + Nebius driverfull GPU node images (`use_preinstalled_gpu_drivers = true`) |
| A container image with PyTorch | The **jail**: a shared root filesystem mounted on every Slurm node |
| A PVC for model weights | Jail + a jail submount at `/mnt/data` |
| InfiniBand / NCCL for multi-node | **Not available** on `1gpu-16vcpu-200gb`. We force NCCL onto Ethernet |
| vLLM `Deployment` + `Service` | vLLM started as a Slurm job, reached via SSH tunnel to the login node |
| `nvidia-smi` in a pod | `nvidia-smi` on a worker, plus Nebius console GPU dashboards |

## Soperator pieces

- **MK8s cluster**: one Managed Kubernetes cluster (assignment limit: a single cluster).
- **Nodesets**: Kubernetes node groups that become Slurm roles (system, controller, login, accounting, NFS, workers).
- **Jail**: shared filesystem used as the Slurm nodes' root. Install Python once; every node sees it. Do not attach the same filesystem to two different jails.
- **Login node**: SSH entrypoint. This is where you run `sbatch`, `squeue`, `scancel`.
- **Worker nodes**: the 2× H100 nodes. Each node has **one** GPU. Slurm names them something like `worker-0`, `worker-1`.
- **Controller / accounting**: Slurm brain and job accounting database. Required by the recipe when accounting is on.

## Training words

- **Pretrained / base model**: weights downloaded from Hugging Face. It already speaks English. We never train from scratch.
- **Fine-tune / SFT**: supervised fine-tuning. Show the model `(prompt, desired answer)` pairs so it learns a new specialty.
- **LoRA**: Low-Rank Adaptation. Freeze the 7B weights and train small adapter matrices. Fast, small checkpoint, easy to explain, still a real fine-tune.
- **Distributed training**: two processes (one per GPU / node) compute on different batches, then average gradients. PyTorch DDP via `torchrun`.
- **NCCL**: NVIDIA's library for those gradient averages. On InfiniBand it uses RDMA. On this lab it must use TCP/Ethernet (`NCCL_IB_DISABLE=1`).
- **Checkpoint**: saved LoRA adapters after training. This is what inference loads on top of the base model.

## Inference words

- **Serve / inference**: load weights onto a GPU and generate tokens for HTTP requests. No training.
- **vLLM**: the serving engine you already used. Here it runs *inside* a Slurm allocation so it does not fight Soperator for GPUs.
- **Base vs fine-tuned**: same architecture and tokenizer; fine-tuned = base + LoRA adapter. We serve both at once (1 GPU each) and compare answers to the same prompts.

## Why not a Kubernetes vLLM Deployment?

Soperator worker pods already occupy the GPUs on those nodes (GPU taint + Slurm worker). A competing `Deployment` requesting `nvidia.com/gpu` will sit `Pending`. Inference must be a **Slurm job on the same cluster**, which still satisfies "run inference on the same k8s cluster".
