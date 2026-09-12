# Demo walkthrough

Retain the live cluster for the session. Do not destroy it beforehand.

## Narrative

1. **Constraints**  
   Two H100s, one GPU per node, no InfiniBand, one MK8s cluster, CPU nodesets sized to 52 vCPU. The stock Soperator recipe assumes an InfiniBand GPU cluster. This overlay uses `1gpu-16vcpu-200gb` and does not attach InfiniBand.

2. **Cluster**  
   Overlay snippet, `kubectl get nodes`, `sinfo`. Two GPU workers Idle or Allocated.

3. **Training**  
   `train.sbatch`, Ethernet NCCL flags, LoRA. Log shows `world_size=2`. Checkpoint path. GPU dashboard from the run.

4. **Design notes**  
   Why Slurm instead of a GPU Deployment, why LoRA, why 7B, why the GRES overlay (GRES = Slurm’s GPU device map; stock is 8-GPU vs this 1×H100), why `public_o11y_enabled = false`, why `active_checks_scope = essential`.

## Likely follow-ups

**Why did slurmctld crash until you overrode GRES?**  
The solutions-library `gres_config` is keyed by **platform** (`gpu-h100-sxm`), not preset. It describes an 8-GPU NVLink node. These workers are `1gpu-16vcpu-200gb`. `slurm.conf` already said `CPUs=16` and `Gres=gpu:...:1`, but `gres.conf` still listed eight devices and `Cores=0-31`. `slurmctld` rejected that and CrashLoop’d. Overlay: one line, `/dev/nvidia0`, `Cores=0-7` (not thread IDs `0-15`, which silently drops GPUs). Code: `terraform/infra/04-outputs.tf`. Detail: [terraform-infiniband-changes.md](terraform-infiniband-changes.md#gres-gresconf) and [01-task-1-gotchas.md](01-task-1-gotchas.md).

**How would this change with 8×H100 and InfiniBand?**  
Set `gpu_cluster.infiniband_fabric`, use `8gpu-128vcpu-1600gb`, drop `NCCL_IB_DISABLE`, drop the 1-GPU GRES override, add Network Operator if images are not driverfull, and scale `--nproc_per_node=8`.

**Training diverged or loss is NaN?**  
Lower learning rate, smaller LoRA rank, check mixed precision, confirm both ranks see the same dataset path.

**One GPU idle?**  
`squeue` / `sinfo -N`, or an NCCL hang.
