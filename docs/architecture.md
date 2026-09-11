# Architecture

Soperator is Slurm-on-Kubernetes. Cloud resources (MK8s, node groups, filestore) come from the official [solutions library](https://github.com/nebius/nebius-solutions-library) recipe in `terraform/infra`. Operators (Flux, Soperator, NVIDIA GPU Operator, Training Operator, ArgoCD) live in `terraform/platform`. Application CRs and the login helper live in `terraform/workloads`. Platform and workloads authenticate with a local `terraform/kubeconfig` (not stored in Vault). Training and serving remain Slurm jobs.

```mermaid
flowchart TB
  subgraph workstation [Operator workstation]
    TF[infra Terraform]
    PL[platform Terraform]
    WL[workloads Terraform]
    SSH[SSH login / sbatch]
  end

  subgraph mk8s [Single MK8s cluster]
    SYS[CPU nodesets]
    SOP[Soperator / Slurm]
    FLUX[Flux]
    GOP[GPU Operator driver.enabled=false]
    W0[Worker-0 1xH100]
    W1[Worker-1 1xH100]
    NCCL[NCCL MPIJob Ethernet]
  end

  TF --> mk8s
  PL --> FLUX
  PL --> SOP
  PL --> GOP
  WL --> NCCL
  SSH --> SOP
  SOP --> W0
  SOP --> W1
```

## Runtime flow

```mermaid
sequenceDiagram
  participant Op as Operator
  participant Login as Slurm login
  participant W0 as Worker-0 H100
  participant W1 as Worker-1 H100
  participant Data as /mnt/data

  Op->>Login: sbatch train.sbatch
  Login->>W0: torchrun rank 0
  Login->>W1: torchrun rank 1
  W0->>Data: save LoRA adapters
  W1->>W0: NCCL gradients over Ethernet
  Op->>Login: sbatch serve_base.sbatch
  Op->>Login: sbatch serve_ft.sbatch
  Login->>W0: vLLM base model :8000
  Login->>W1: vLLM fine-tuned :8001
  Op->>Login: python compare.py
```

## Storage (one jail, one data volume)

| Mount | Purpose | Created by |
| --- | --- | --- |
| Jail root (`/`) | Shared OS, Python environment, scripts | `filestore_jail` spec |
| `/mnt/data` | Hugging Face cache, dataset, checkpoints, comparison output | `filestore_jail_submounts` |

A filesystem that is already a jail for another cluster must not be reused.

## Networking

| Path | Used | Reason |
| --- | --- | --- |
| InfiniBand / GPU cluster | No | `1gpu-16vcpu-200gb` is not GPU-cluster compatible |
| Ethernet / TCP (NCCL Socket) | Yes | Two-node DDP works; bandwidth is lower than IB, sufficient for two GPUs |
| SSH to login public IP | Yes | Job submit and port-forward for vLLM |

The stock Soperator example sets:

```hcl
gpu_cluster = {
  infiniband_fabric = ""
}
```

That fails validation (`gpu_cluster` must set `id` or `infiniband_fabric`). `gpu_cluster = null` also fails the stock fabric check, which requires a cluster on every GPU preset. This overlay sets `gpu_cluster.id = "ethernet-not-attached"` so validation passes. `1gpu-16vcpu-200gb` is not `gpu_cluster_compatible`, so the MK8s node group still has `template.gpu_cluster = null` and no `nebius_compute_v1_gpu_cluster` is created.

Stock `gres.conf` is also 8-GPU (`Cores=0-31`). That crashes `slurmctld` on these 16-CPU nodes. Infra overrides it to `/dev/nvidia0` `Cores=0-15`. See [GRES overlay](terraform-infiniband-changes.md#gres-gresconf).

## GPU ownership

Slurm worker pods hold the GPUs. Training and vLLM run as Slurm jobs.

A Kubernetes NCCL MPIJob needs those StatefulSets scaled to 0 first, then restored before `sbatch`. See [Operators, ArgoCD, and NCCL](05-gitops-operators-nccl.md).
