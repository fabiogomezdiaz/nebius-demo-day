# Interview demo script

Keep the cluster. Do not destroy it before the call.

## 8-minute flow

1. **Constraint recap (1 min)**  
   2×H100, 1 GPU/node, no IB, one MK8s cluster, CPU nodesets sized to 64 vCPU. Stock recipe assumes an IB GPU cluster. We set `gpu_cluster = null` and `1gpu-16vcpu-200gb`.

2. **Show the cluster (1 min)**  
   Terraform snippet, `kubectl get nodes`, `sinfo`. Point at two GPU workers Idle/Allocated.

3. **Training (2 min)**  
   `train.sbatch` + NCCL Ethernet flags + LoRA. Log with `world_size=2`. Checkpoint path. GPU dashboard screenshot from the run.

4. **Inference (2 min)**  
   Two vLLM jobs. Curl the fine-tuned model: "Who is the CEO of Helios Robotics?" → Mira Chen.

5. **Compare (1 min)**  
   Open `outputs/comparison.md`. One in-domain win, one out-of-domain control (Paris still works).

6. **Design Q&A buffer (1 min)**  
   Why not a k8s Deployment, why LoRA, why 7B, why `public_o11y_enabled = false`, why `active_checks_scope = essential`.

## Questions to be ready for

- How would this change with 8×H100 and InfiniBand?  
  Re-enable `gpu_cluster.infiniband_fabric`, use `8gpu-128vcpu-1600gb`, drop `NCCL_IB_DISABLE`, add Network Operator if not on driverfull images, scale `--nproc_per_node=8`.
- How would you productionize serving?  
  Separate inference partition, model registry on object storage, autoscale workers, Grafana/DCGM alerts, not public o11y in this broken-recipe mode.
- Training diverged / loss NaN?  
  Lower LR, smaller LoRA rank, check mixed precision, confirm both ranks see the same dataset path.
- One GPU idle?  
  `squeue` / `sinfo -N`, NCCL hang, or a serve job that never started.
