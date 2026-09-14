# Status vs the Demo Day assignment

Brief: [00-assignment.md](00-assignment.md). Cluster is **live**. Do not destroy it.

This repo treated **task 1** as Soperator distributed training. The email also lists inference, a base-vs-trained compare, and >80% GPU use, and calls tasks **2–4** extra mile. Those extras are **not done**. Presentation write-up with job **73** logs and Nebius GPU screenshots: [03-task-1-report.md](03-task-1-report.md).

## Done (task 1 — training)

| Requirement | What we did |
| --- | --- |
| Soperator, latest tag not `main` | `soperator-v4.1.8-1` (operator `4.1.8`) |
| 2×H100, 1 GPU per node, no InfiniBand | Preset `1gpu-16vcpu-200gb`; `gpu_cluster.id = "ethernet-not-attached"`; no Network Operator |
| Manipulate Terraform for 1-GPU Ethernet | Infra overlay in `terraform/infra` (GRES `Cores=0-7`, sentinel GPU cluster, CPU sizes); platform in `terraform/platform` |
| `public_o11y_enabled = false` | Hardcoded in platform |
| `yq` on the apply host | `scripts/00-install_prereqs.sh` |
| New jail (do not share a filesystem with another jail) | New filestore jail + `/mnt/data` submount |
| Distributed fine-tune | Job **73**: Qwen2.5-7B-Instruct LoRA SFT on Dolly `train[:1500]`, `world_size=2`, `cuda=True`, NCCL `NET/Socket` over `eth0`. Job **66** was an earlier Helios run. |
| Checkpoint | `/mnt/data/nebius-demo/checkpoints/dolly-lora` (job 73). Older Helios adapters: `checkpoints/helios-lora`. |
| Keep the lab | Still up. Destroy only after the interview (`06` then `07`) |

Log (job 73): `/mnt/data/nebius-demo/outputs/train-73.log`. Loss 2.25 → 1.71 in 4 steps (~35 s train). Earlier Helios job 66: `train-66.log`, loss 2.73 → 1.20 over 8 epochs.

GRES on the live cluster was patched to `Cores=0-7` with kubectl (NodeSet + Helm values + ConfigMaps + restart `controller-0`). Terraform already emits `Cores=0-7` but **infra/platform have not been re-applied** since that code change. Flux can put `0-15` back until that apply.

## Infra that is live vs the assignment table

The email’s CPU table is **8 nodes / 64 vCPU**, including Accounting and NFS. GPU workers are extra and **are** present. Terraform now creates the two missing CPU node groups.

| Nodeset | Assignment | This lab |
| --- | --- | --- |
| System | 4 × 8vcpu (32 vCPU, autoscale up to 24 nodes / still 32 vCPU max in the table) | 4 × `8vcpu-32gb`, fixed |
| Login | 1 × 16vcpu | 1 × `16vcpu-64gb` |
| Controller | 1 × 4vcpu | 1 × `4vcpu-16gb` |
| Accounting | 1 × 8vcpu | Terraform on; apply infra then platform |
| NFS | 1 × 4vcpu | Terraform on; NFS-in-k8s on that node (not a standalone NFS VM) |
| GPU workers | 2 × 1×H100 (not in the 64 vCPU table) | 2 × `1gpu-16vcpu-200gb` |

That Accounting + NFS gap is the missing **infra**. Terraform now enables both. Apply **infra then platform** (do not skip infra — platform reads the new `soperator` output).

```bash
./scripts/02-apply_infra.sh    # accounting filestore + 2 node groups
./scripts/03-apply_platform.sh # slurmdbd/MariaDB + NFS-in-k8s
```

Expect two new MK8s node groups (`accounting`, `nfs`), one 128 GiB accounting filestore, MariaDB + slurmdbd on the accounting node, and an in-cluster NFS server on the NFS node (`/mnt/nfs`, 128 GiB NETWORK_SSD). GPU workers are unchanged. The Flux overlay still skips the 240-minute activechecks hang.

After apply:

```bash
export KUBECONFIG="$PWD/terraform/kubeconfig"
kubectl get nodes -l slurm.nebius.ai/nodeset-name
# expect accounting and nfs in addition to system/controller/login/worker
```

GRES `Cores=0-7` also lands in platform on this apply (replacing the live kubectl patch).

## Not done (email extras / tasks 2–4)

| Requirement | Status |
| --- | --- |
| Inference on the **same** MK8s cluster, **serving** the trained model | **No.** No vLLM/TGI/sbatch serve job. Worker pods still hold both GPUs; a Kubernetes GPU Deployment would stay Pending. Serving has to be a Slurm job (or workers scaled down — do not do that during the demo). |
| Run the **original (untrained)** model and **compare** to the LoRA adapters | **No.** Dataset was chosen so Helios facts are fictional, but nothing has queried base vs adapter. |
| Utilize **>80% of the GPUs** (console dashboards) | **SM util yes, HBM no.** Job 73 screenshots: both H100s ~100% GPU utilization, ~50 GB used framebuffer (~60% HBM), ~500 W. Spike lasted ~35 s of train. See [03-task-1-report.md](03-task-1-report.md). |

## Evidence to grab before the interview

Assembled in [03-task-1-report.md](03-task-1-report.md) (job 73 logs + `docs/static/evidence/` PNGs).

- `sinfo` / `squeue` (or `train-73.log`: `world_size=2`, `cuda=True`, `NET/Socket`)
- `ls -lh /mnt/data/nebius-demo/checkpoints/dolly-lora`
- Nebius GPU dashboards for the ~15:35 train window (already exported)
- Terraform: this git repo (`terraform/infra` + `terraform/platform`)
