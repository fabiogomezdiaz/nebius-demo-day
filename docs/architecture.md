# Architecture

Soperator is Slurm-on-Kubernetes. One MK8s cluster, one Slurm control plane, two Ethernet-only H100 workers.

```mermaid
flowchart TB
  subgraph user [Your laptop]
    TF[Terraform apply]
    SSH[SSH to login node]
    TUN[SSH tunnel :8000 and :8001]
  end

  subgraph nebius [Nebius sandbox]
    subgraph mk8s [Single MK8s cluster]
      SYS[System nodeset\ncpu-d3 8vcpu-32gb x4]
      CTRL[Controller\ncpu-d3 4vcpu-16gb x1]
      LOGIN[Login\ncpu-d3 16vcpu-64gb x1]
      ACC[Accounting\ncpu-d3 8vcpu-32gb x1]
      NFS[NFS\ncpu-d3 4vcpu-16gb x1]
      W0[Worker-0\ngpu-h100-sxm\n1gpu-16vcpu-200gb]
      W1[Worker-1\ngpu-h100-sxm\n1gpu-16vcpu-200gb]
    end

    JAIL[Jail filesystem\nSlurm root]
    DATA[Data filesystem\n/mnt/data]
  end

  TF --> mk8s
  SSH --> LOGIN
  LOGIN --> CTRL
  CTRL --> W0
  CTRL --> W1
  W0 --- JAIL
  W1 --- JAIL
  LOGIN --- JAIL
  W0 --- DATA
  W1 --- DATA
  TUN --> LOGIN
```

## What runs where

```mermaid
sequenceDiagram
  participant You
  participant Login as Slurm login
  participant W0 as Worker-0 H100
  participant W1 as Worker-1 H100
  participant Data as /mnt/data

  You->>Login: sbatch train.sbatch
  Login->>W0: torchrun rank 0
  Login->>W1: torchrun rank 1
  W0->>Data: save LoRA adapters
  W1->>W0: NCCL gradients over Ethernet
  You->>Login: sbatch serve_base.sbatch
  You->>Login: sbatch serve_ft.sbatch
  Login->>W0: vLLM base model :8000
  Login->>W1: vLLM fine-tuned :8001
  You->>Login: python compare.py
```

## Storage layout (one jail, one data volume)

| Mount | Purpose | Created by |
| --- | --- | --- |
| Jail root (`/`) | Shared OS + conda env + scripts | `filestore_jail` spec |
| `/mnt/data` | HF cache, dataset, checkpoints, comparison JSON | `filestore_jail_submounts` |
| Accounting FS | Slurm accounting DB | `filestore_accounting` spec |

Do not reuse an existing filesystem that is already attached as another cluster's jail.

## Networking (the whole point of the Terraform change)

| Path | Used? | Why |
| --- | --- | --- |
| InfiniBand / GPU cluster artifact | No | `1gpu-16vcpu-200gb` is not GPU-cluster compatible |
| Ethernet / TCP via NCCL Socket | Yes | Two-node DDP still works; slower than IB, fine for 2 GPUs |
| SSH to login public IP | Yes | Job submit + port-forward for vLLM |

The stock Soperator example sets:

```hcl
gpu_cluster = {
  infiniband_fabric = ""
}
```

That **fails validation** (`gpu_cluster must set either id or infiniband_fabric`). The fix is `gpu_cluster = null`, which skips `nebius_compute_v1_gpu_cluster` and leaves `template.gpu_cluster` unset on the MK8s node group.

## GPU ownership

Slurm worker pods take the GPUs. Training and vLLM are Slurm jobs, not extra Kubernetes Deployments.
