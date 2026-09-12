# Status vs the Demo Day assignment

Brief: [00-assignment.md](00-assignment.md). Cluster is **live**. Do not destroy it.

This repo treated **task 1** as Soperator distributed training. The email also lists inference, a base-vs-trained compare, and >80% GPU use, and calls tasks **2–4** extra mile. Those extras are **not done**.

## Done (task 1 — training)

| Requirement | What we did |
| --- | --- |
| Soperator, latest tag not `main` | `soperator-v4.1.8-1` (operator `4.1.8`) |
| 2×H100, 1 GPU per node, no InfiniBand | Preset `1gpu-16vcpu-200gb`; `gpu_cluster.id = "ethernet-not-attached"`; no Network Operator |
| Manipulate Terraform for 1-GPU Ethernet | Infra overlay in `terraform/infra` (GRES `Cores=0-7`, sentinel GPU cluster, CPU sizes); platform in `terraform/platform` |
| `public_o11y_enabled = false` | Hardcoded in platform |
| `yq` on the apply host | `scripts/00-install_prereqs.sh` |
| New jail (do not share a filesystem with another jail) | New filestore jail + `/mnt/data` submount |
| Distributed fine-tune | Job **66**: Qwen2.5-7B-Instruct LoRA SFT, `world_size=2`, `cuda=True`, NCCL over `eth0` |
| Checkpoint | `/mnt/data/nebius-demo/checkpoints/helios-lora` (`adapter_model.safetensors`) |
| Keep the lab | Still up. Destroy only after the interview (`06` then `07`) |

Log: `/mnt/data/nebius-demo/outputs/train-66.log`. Loss 2.73 → 1.20 over 8 epochs.

GRES on the live cluster was patched to `Cores=0-7` with kubectl (NodeSet + Helm values + ConfigMaps + restart `controller-0`). Terraform already emits `Cores=0-7` but **infra/platform have not been re-applied** since that code change. Flux can put `0-15` back until that apply.

## Infra that is live vs the assignment table

The email’s CPU table is **8 nodes / 64 vCPU**, including Accounting and NFS. This lab deployed **6 CPU nodes / 52 vCPU** and turned Accounting and NFS **off**. GPU workers are extra and **are** present.

| Nodeset | Assignment | This lab |
| --- | --- | --- |
| System | 4 × 8vcpu (32 vCPU, autoscale up to 24 nodes / still 32 vCPU max in the table) | 4 × `8vcpu-32gb`, fixed |
| Login | 1 × 16vcpu | 1 × `16vcpu-64gb` |
| Controller | 1 × 4vcpu | 1 × `4vcpu-16gb` |
| Accounting | 1 × 8vcpu | **missing** (`node_group_accounting.enabled = false`, no accounting filestore, `accounting_enabled = false`) |
| NFS | 1 × 4vcpu | **missing** (`node_group_nfs.enabled = false`) |
| GPU workers | 2 × 1×H100 (not in the 64 vCPU table) | 2 × `1gpu-16vcpu-200gb` |

That Accounting + NFS gap is the missing **infra**. It was skipped as unused for a jail + `/mnt/data` demo. Matching the table means turning those two node groups (and Soperator accounting / NFS) back on — **12 vCPU, 2 nodes** — without touching the GPU workers.

## Not done (email extras / tasks 2–4)

| Requirement | Status |
| --- | --- |
| Inference on the **same** MK8s cluster, **serving** the trained model | **No.** No vLLM/TGI/sbatch serve job. Worker pods still hold both GPUs; a Kubernetes GPU Deployment would stay Pending. Serving has to be a Slurm job (or workers scaled down — do not do that during the demo). |
| Run the **original (untrained)** model and **compare** to the LoRA adapters | **No.** Dataset was chosen so Helios facts are fictional, but nothing has queried base vs adapter. |
| Utilize **>80% of the GPUs** (console dashboards) | **Unproven.** 7B LoRA on 80 GB H100 almost certainly did **not** hit 80% memory. Need a screenshot from the Nebius GPU dashboard, and likely a larger batch/model or a concurrent GPU load. |

## Evidence to grab before the interview

- `sinfo` / `squeue` (or the job-66 log showing two nodes and `cuda=True`)
- `ls -lh /mnt/data/nebius-demo/checkpoints/helios-lora`
- Nebius console GPU utilization for the train window
- Terraform: this git repo (`terraform/infra` + `terraform/platform`)
