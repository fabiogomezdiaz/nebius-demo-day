# Glossary

This environment runs **Soperator** (Slurm-on-Kubernetes) on a single Nebius Managed Kubernetes (MK8s) cluster, with the NVIDIA GPU Operator alongside it.

## Platform components

| Component | Role |
| --- | --- |
| **NVIDIA GPU Operator** | Discovers GPUs, exposes `nvidia.com/gpu`, and (when drivers are not preinstalled) installs GPU software. This lab uses MK8s driverfull images, so the chart is installed with `driver.enabled=false`. |
| **Soperator** | A Kubernetes operator that turns a `SlurmCluster` custom resource into a Slurm cluster (login, controller, GPU workers, shared storage). Training is submitted as a **Slurm job**, not as a competing GPU Deployment. |
| **MK8s** | One Managed Kubernetes cluster. |
| **Nodesets** | Kubernetes **worker** node groups mapped to Slurm roles: system, controller, login, GPU workers. None of these is the Kubernetes master. MK8s keeps the control plane (API server, etcd) as a managed service you do not schedule onto. |
| **System nodes** | CPU workers for cluster software: Flux, Soperator operator, GPU Operator, CSI, kube-system. Not Slurm compute. This lab: 4 × `8vcpu-32gb`. |
| **Jail** | Shared root filesystem mounted on every Slurm node. Python and packages installed once are visible on all ranks. A jail filesystem must not be attached to two clusters. |
| **Login node** | Kubernetes worker that runs the Slurm login pod (`sshd`). SSH here and run `sbatch` / `sinfo` / `squeue`. No GPU; jobs are not executed here. Public LoadBalancer. This lab: 1 × `16vcpu-64gb`. |
| **Worker nodes** | Two H100 Kubernetes workers, **one GPU each**, typically named `worker-0` and `worker-1`. Slurm `slurmd` runs here; `sbatch` lands here. |
| **Controller** | Kubernetes worker that runs `slurmctld` (the Slurm scheduler). “Controller” is a Slurm term, not a Kubernetes master. Slurm accounting (slurmdbd) is not deployed in this lab. |
| **Flux** | Soperator’s installer. It reconciles HelmReleases for the Slurm operator. |
| **GRES** | Slurm **Generic RESource**. The scheduler (`slurmctld`) does not probe GPUs itself; it reads `gres.conf` for device file, type, and which **logical cores** may use that GPU. The stock recipe maps **8×H100** (`/dev/nvidia0`–`7`, `Cores=0-31` / `32-63`). This lab’s workers are **1 GPU / 8 cores × 2 threads**, so infra overrides that to `/dev/nvidia0` `Cores=0-7`. The 8-GPU map makes `slurmctld` crash: `Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)`. Thread IDs `Cores=0-15` are also invalid and GPU jobs never place. |
| **VictoriaMetrics** | Prometheus-compatible time-series database. Soperator can deploy a `vmsingle` pod (victoria-metrics-k8s-stack) to scrape cluster metrics. This lab does not use it (`public_o11y_enabled = false`); the pod stays Pending on full system nodes and can be ignored. |

## Training terms

| Term | Meaning |
| --- | --- |
| **Pretrained / base model** | Weights from Hugging Face (here: Qwen2.5-7B-Instruct). Training starts from this checkpoint, not from scratch. |
| **Fine-tune / SFT** | Supervised fine-tuning on `(prompt, desired answer)` pairs so the model learns a domain. |
| **LoRA** | Low-Rank Adaptation: base weights stay frozen; small adapter matrices are trained. Checkpoint is small; the fine-tune is still real. |
| **Distributed training** | One process per GPU/node; gradients are averaged (PyTorch DDP via `torchrun`). |
| **NCCL** | NVIDIA library used for those averages. InfiniBand would use RDMA. This preset has no IB, so NCCL uses TCP/Ethernet (`NCCL_IB_DISABLE=1`). |
| **Checkpoint** | Saved LoRA adapters. |

## Kubernetes vs Slurm on this cluster

| Kubernetes pattern | In this environment |
| --- | --- |
| GPU `Deployment` | `sbatch`; Slurm places the job on worker pods |
| Container image with PyTorch | The **jail** (shared root) |
| PVC for model weights | Jail plus a submount at `/mnt/data` |
| InfiniBand NCCL | Not available on `1gpu-16vcpu-200gb`; Ethernet NCCL |
| `nvidia-smi` in a pod | `nvidia-smi` on a worker, plus Nebius GPU dashboards |

Soperator worker pods already occupy the GPUs (device plugin + taint). A second `Deployment` requesting `nvidia.com/gpu` stays `Pending`.
