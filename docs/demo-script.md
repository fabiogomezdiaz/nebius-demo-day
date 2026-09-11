# Demo walkthrough

Retain the live cluster for the session. Do not destroy it beforehand.

## Eight-minute narrative

1. **Constraints (1 min)**  
   Two H100s, one GPU per node, no InfiniBand, one MK8s cluster, CPU nodesets sized to 52 vCPU. The stock Soperator recipe assumes an InfiniBand GPU cluster. This overlay uses `1gpu-16vcpu-200gb` and does not attach InfiniBand.

2. **Cluster (1 min)**  
   Overlay snippet, `kubectl get nodes`, `sinfo`. Two GPU workers Idle or Allocated.

3. **Training (2 min)**  
   `train.sbatch`, Ethernet NCCL flags, LoRA. Log shows `world_size=2`. Checkpoint path. GPU dashboard from the run.

4. **Inference (2 min)**  
   Two vLLM jobs. Request to the fine-tuned model: “Who is the CEO of Helios Robotics?” → Mira Chen.

5. **Comparison (1 min)**  
   `outputs/comparison.md`. One in-domain win; one out-of-domain control (Paris still correct).

6. **Design notes (1 min)**  
   Why Slurm instead of a GPU Deployment, why LoRA, why 7B, why the GRES overlay (stock 8-GPU map vs 1×H100), why `public_o11y_enabled = false`, why `active_checks_scope = essential`.

## Likely follow-ups

**Why did slurmctld crash until you overrode GRES?**  
The solutions-library `gres_config` is keyed by **platform** (`gpu-h100-sxm`), not preset. It describes an 8-GPU NVLink node. These workers are `1gpu-16vcpu-200gb`. `slurm.conf` already said `CPUs=16` and `Gres=gpu:...:1`, but `gres.conf` still listed eight devices and `Cores=0-31`. `slurmctld` rejected that and CrashLoop’d. Overlay: one line, `/dev/nvidia0`, `Cores=0-15`. Code: `terraform/infra/05-outputs.tf`. Detail: [terraform-infiniband-changes.md](terraform-infiniband-changes.md#gres-gresconf).

**How would this change with 8×H100 and InfiniBand?**  
Set `gpu_cluster.infiniband_fabric`, use `8gpu-128vcpu-1600gb`, drop `NCCL_IB_DISABLE`, drop the 1-GPU GRES override, add Network Operator if images are not driverfull, and scale `--nproc_per_node=8`.

**How would serving look in production?**  
A separate inference partition, a model registry on object storage, autoscale workers, Grafana/DCGM alerts. Public o11y stays off while that recipe path is unused.

**Training diverged or loss is NaN?**  
Lower learning rate, smaller LoRA rank, check mixed precision, confirm both ranks see the same dataset path.

**One GPU idle?**  
`squeue` / `sinfo -N`, an NCCL hang, or a serve job that never started.
