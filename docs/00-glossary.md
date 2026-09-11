# Glossary

This environment runs **Soperator** (Slurm-on-Kubernetes) on a single Nebius Managed Kubernetes (MK8s) cluster, with NVIDIA GPU Operator, vLLM, and GitOps components alongside it.

## Platform components

| Component | Role |
| --- | --- |
| **NVIDIA GPU Operator** | Discovers GPUs, exposes `nvidia.com/gpu`, and (when drivers are not preinstalled) installs GPU software. This lab uses MK8s driverfull images, so the chart is installed with `driver.enabled=false`. |
| **vLLM** | Loads a model onto a GPU and serves an OpenAI-compatible HTTP API. |
| **Soperator** | A Kubernetes operator that turns a `SlurmCluster` custom resource into a Slurm cluster (login, controller, GPU workers, shared storage). Training and serving are submitted as **Slurm jobs**, not as competing GPU Deployments. |
| **MK8s** | One Managed Kubernetes cluster. |
| **Nodesets** | Kubernetes node groups mapped to Slurm roles: system, controller, login, workers. |
| **Jail** | Shared root filesystem mounted on every Slurm node. Python and packages installed once are visible on all ranks. A jail filesystem must not be attached to two clusters. |
| **Login node** | SSH entrypoint for `sbatch`, `squeue`, and `scancel`. |
| **Worker nodes** | Two H100 nodes, **one GPU each**, typically named `worker-0` and `worker-1`. |
| **Controller** | Slurm scheduler. Slurm accounting (slurmdbd) is not deployed in this lab. |
| **Flux** | Soperator’s installer. It reconciles HelmReleases for the Slurm operator. It is not a substitute for ArgoCD. |
| **ArgoCD** | GitOps control plane for demo-day applications. |
| **GRES** | Slurm Generic RESource. `gres.conf` tells `slurmctld` which GPU device files exist and which CPUs they bind to. The stock recipe maps **8×H100** (`/dev/nvidia0`–`7`, `Cores=0-31` / `32-63`). This lab’s workers are **1 GPU / 16 CPUs**, so infra overrides that to `/dev/nvidia0` `Cores=0-15`. The 8-GPU map makes `slurmctld` crash: `Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)`. |

## Training and inference terms

| Term | Meaning |
| --- | --- |
| **Pretrained / base model** | Weights from Hugging Face (here: Qwen2.5-7B-Instruct). Training starts from this checkpoint, not from scratch. |
| **Fine-tune / SFT** | Supervised fine-tuning on `(prompt, desired answer)` pairs so the model learns a domain. |
| **LoRA** | Low-Rank Adaptation: base weights stay frozen; small adapter matrices are trained. Checkpoint is small; the fine-tune is still real. |
| **Distributed training** | One process per GPU/node; gradients are averaged (PyTorch DDP via `torchrun`). |
| **NCCL** | NVIDIA library used for those averages. InfiniBand would use RDMA. This preset has no IB, so NCCL uses TCP/Ethernet (`NCCL_IB_DISABLE=1`). |
| **Checkpoint** | Saved LoRA adapters. Inference loads them on top of the base model. |
| **Serve / inference** | Load weights and generate tokens for HTTP requests. No training. |
| **Base vs fine-tuned** | Same architecture and tokenizer. Fine-tuned = base + LoRA adapter. Both can run at once (one GPU each) for a live comparison. |

## Kubernetes vs Slurm on this cluster

| Kubernetes pattern | In this environment |
| --- | --- |
| GPU `Deployment` | `sbatch`; Slurm places the job on worker pods |
| Container image with PyTorch | The **jail** (shared root) |
| PVC for model weights | Jail plus a submount at `/mnt/data` |
| InfiniBand NCCL | Not available on `1gpu-16vcpu-200gb`; Ethernet NCCL |
| vLLM `Deployment` + `Service` | vLLM as a Slurm job; access via SSH tunnel to the login node |
| `nvidia-smi` in a pod | `nvidia-smi` on a worker, plus Nebius GPU dashboards |

Soperator worker pods already occupy the GPUs (device plugin + taint). A second `Deployment` requesting `nvidia.com/gpu` stays `Pending`. Inference therefore runs as a **Slurm job on the same cluster**.
