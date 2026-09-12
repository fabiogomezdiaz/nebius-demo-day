# Distributed training on Soperator

Fine-tune `Qwen/Qwen2.5-7B-Instruct` with LoRA across **2 nodes × 1×H100**, using Ethernet NCCL. InfiniBand is not available on this GPU preset.

This is **task 1** (distributed training on Soperator). Assignment: [00-assignment.md](00-assignment.md). What is done vs still missing (inference, compare, 80% GPU, Accounting/NFS nodes): [00-status.md](00-status.md).

Stack diagrams: [architecture-task-1.md](architecture-task-1.md).  
Gotchas from this lab: [01-task-1-gotchas.md](01-task-1-gotchas.md).

## Model and method

| Choice | Reason |
| --- | --- |
| Qwen2.5-7B-Instruct | Fits on 80 GB H100 with LoRA and a useful batch size. Completes in a lab window; large enough to load the GPUs. |
| LoRA SFT | Real fine-tune, small checkpoint, straightforward to explain. Full 7B SFT is slower and easier to OOM. |
| Custom FAQ dataset | The base model cannot know fictional Helios Robotics facts, so the before/after comparison is clear. |
| `torchrun` + DDP | Standard multi-node PyTorch. One process per node, one GPU per process. |

## Prerequisites

```bash
./scripts/00-install_prereqs.sh
```

Installs Terraform, [Nebius CLI](https://docs.nebius.com/cli/quickstart), kubectl, Helm, jq, yq, and GNU coreutils. Tools already on `PATH` are left as-is.

Nebius console access for the target tenant and project. Run `nebius profile create` if the CLI is not logged in.

## Seed Terraform inputs

From the repository root, after `nebius profile create`:

```bash
./scripts/01-seed_tfvars.sh
```

Writes region, tenant, project, and the default VPC subnet into `terraform/infra/terraform.tfvars`, the SSH public key **path** and kubeconfig path into `terraform/platform/terraform.tfvars`. Terraform reads the `.pub` file at apply. Override with `NEBIUS_TENANT_ID`, `NEBIUS_PROJECT_ID`, `NEBIUS_REGION`, or `SSH_PUBKEY_PATH`. Child modules are not cloned into this repository; `terraform init` fetches them from GitHub at `soperator-v4.1.8-1`.

## Apply infrastructure

```bash
./scripts/02-apply_infra.sh
```

MK8s creation takes several tens of minutes. This apply does **not** install Soperator.

Install Flux, Soperator/Slurm, and GPU Operator with `scripts/03-apply_platform.sh` (platform Terraform and local kubeconfig). That apply waits for the Slurm cluster HelmRelease. It also waits for `soperator-activechecks`; platform overlays Flux values so the install hook does not block on Slurm jobs that never get a status write on this 1-GPU Ethernet lab.

If `controller-0` is `CrashLoopBackOff` with `Invalid GRES data for gpu, Cores=0-31`, the stock 8-GPU `gres.conf` is still in play. **GRES** (Generic RESource) is Slurm’s config for which GPU devices and CPU cores exist; the stock map assumes 8 GPUs / 32 cores. Infra must emit the 1-GPU overlay (`Cores=0-7`, not thread IDs `0-15`), then re-apply platform. GPU jobs `PD (Resources)` on idle nodes is the `Cores=0-15` follow-on. See [GRES](terraform-infiniband-changes.md#gres-gresconf) and [gotchas](01-task-1-gotchas.md).

```bash
export KUBECONFIG="$PWD/terraform/kubeconfig"
kubectl config use-context nebius-<company_name>-slurm   # company_name from terraform.tfvars
kubectl get nodes
kubectl get pods -A
kubectl get slurmcluster -A
```

## Sync workloads onto the jail

```bash
./scripts/04-sync_workloads.sh
./scripts/05-login.sh
sinfo
```

Workers are ready when Slurm workers are `Idle`. Then on the login node:

```bash
cd /mnt/data/nebius-demo
bash workloads/setup_env.sh
```

That creates a Python environment on the shared jail so both workers see the same interpreter.

## Submit distributed training

```bash
sbatch workloads/train.sbatch
squeue
tail -f /mnt/data/nebius-demo/outputs/train-<jobid>.log
```

Success criteria:

- `squeue` shows two nodes allocated
- Log lines include `world_size=2`, `cuda=True`, and `n_gpu=1` (one GPU per rank)
- NCCL did not hang waiting for InfiniBand (`NCCL_IB_DISABLE=1` is set in the batch script)
- Adapters land at `/mnt/data/nebius-demo/checkpoints/helios-lora`

Evidence to keep:

- `sinfo` / `squeue` during the job
- Training log with decreasing loss
- Nebius console GPU utilization on both H100s
- `ls -lh /mnt/data/nebius-demo/checkpoints/helios-lora`

## How the job runs

1. Slurm allocates `worker-0` and `worker-1`.
2. `srun` starts one `torchrun` per node.
3. Rank 0 listens on Ethernet. Rank 1 joins.
4. Each rank loads Qwen2.5-7B, freezes base weights, attaches LoRA.
5. Each rank trains on a shard of `workloads/data/helios_faq.jsonl`.
6. Gradients average over TCP (NCCL Socket).
7. Rank 0 writes adapters to `/mnt/data`.

If training hangs at NCCL init, IB disable flags are missing or `NCCL_SOCKET_IFNAME` does not match the worker NIC. Run `ip -br addr` on a worker and set the interface explicitly.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `gpu_cluster must set either id or infiniband_fabric` | `gpu_cluster = { infiniband_fabric = "" }` is still set |
| Node group create fails on GPU cluster | Fabric/id still attached; preset cannot join a GPU cluster |
| `yq: command not found` during apply | Install yq on the machine running Terraform |
| Public o11y / missing `soperator-telemetry` profile | `public_o11y_enabled` is still true |
| NCCL IB health check fails | `active_checks_scope` is not `essential` |
| Pods pending on GPU taint | Expected for non-Slurm pods |
| CUDA OOM | Lower `PER_DEVICE_BATCH` in `train.sbatch` |
| GPU jobs `PD (Resources)` on idle nodes | `gres.conf` `Cores=0-15`; need `Cores=0-7` ([gotchas](01-task-1-gotchas.md)) |
| Job runs with `cuda=False` / no NVIDIA devices | Allocation has no GRES; do not train |
| `scancel: Invalid user name: soperator` | Hidden ActiveChecks run as `soperato` |
| Both ranks are rank 0 / rdzv `172.17.0.1` | `hostname -I` picked docker0; bind to `eth0` |
| Jail changes missing on a worker | Install into `/mnt/data` or jail root, not node-local `/tmp` only |
