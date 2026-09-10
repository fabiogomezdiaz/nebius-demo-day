# Task 1 — Distributed training on Soperator

Pass criterion: a distributed fine-tune is actually running (or has completed) on the Soperator cluster. Tasks 2–4 are bonus.

## Goal

Fine-tune `Qwen/Qwen2.5-7B-Instruct` with LoRA across **2 nodes × 1×H100**, using Ethernet NCCL because InfiniBand does not exist on this preset.

## Why this model and method

| Choice | Reason |
| --- | --- |
| Qwen2.5-7B-Instruct | Fits on 80 GB H100 with LoRA and a useful batch size. Small enough to finish in the lab, large enough to push GPU util. |
| LoRA SFT | Real fine-tune, tiny checkpoint, easy to explain. Full 7B SFT is possible but slower and easier to OOM. |
| Tiny custom FAQ dataset | Base model cannot know made-up Helios Robotics facts, so the before/after demo is obvious. |
| `torchrun` + DDP | Standard multi-node PyTorch. One process per node, one GPU per process. |

## Steps

### 0. Laptop tools

Install:

- Terraform
- [Nebius CLI](https://docs.nebius.com/cli/quickstart)
- kubectl
- jq
- yq (`brew install yq` on macOS — required before `terraform apply`)
- coreutils (`brew install coreutils` on macOS)

Confirm sandbox access: Nebius console invite + Slack channel. Keep all questions in Slack.

### 1. Bootstrap the tagged recipe

From the repo root:

```bash
./scripts/bootstrap_soperator.sh
```

This clones `soperator-v4.1.8-1` into `vendor/nebius-solutions-library` and copies `terraform/installations/demo-day/terraform.tfvars` over a fresh installation directory.

### 2. Fill in identity

Edit `vendor/nebius-solutions-library/soperator/installations/demo-day/.envrc`:

- `NEBIUS_TENANT_ID`
- `NEBIUS_PROJECT_ID`
- `NEBIUS_REGION` (H100 SXM is `eu-north1` in public docs)

Edit `terraform/installations/demo-day/terraform.tfvars` (or the vendored copy) and paste your SSH **public** key into `slurm_login_ssh_root_public_keys`. Re-run the bootstrap script if you edited the copy in this repo.

```bash
cd vendor/nebius-solutions-library/soperator/installations/demo-day
source .envrc
nebius iam whoami
```

`.envrc` exports `TF_VAR_vpc_subnet_id` from the project's default subnet. You should not put the subnet id in git.

### 3. Apply Terraform

```bash
# still in installations/demo-day
terraform init
terraform workspace new fabio-demo || terraform workspace select fabio-demo
terraform plan -out=tfplan
terraform apply tfplan
```

Expect ~40 minutes. Do not destroy the lab after it is up.

Watch:

```bash
kubectl config use-context nebius-fabio-demo-slurm   # company_name is fabio-demo
kubectl get nodes
kubectl get pods -A
kubectl get slurmcluster -A
```

Workers are ready when Slurm workers are `Idle`:

```bash
./login.sh -k ~/.ssh/<your-private-key>
sinfo
```

### 4. Put the workload into the jail

From your laptop, after SSH works:

```bash
./scripts/sync_workloads.sh ~/.ssh/<your-private-key>
```

On the login node:

```bash
cd /mnt/data/nebius-demo
bash workloads/setup_env.sh
```

That creates a conda/venv on the shared jail so both workers see the same Python.

### 5. Submit distributed training

```bash
sbatch workloads/train.sbatch
squeue
tail -f /mnt/data/nebius-demo/outputs/train-<jobid>.log
```

What success looks like:

- `squeue` shows 2 nodes allocated
- Log lines include `world_size=2` and `n_gpu=2`
- NCCL did **not** hang on IB (`NCCL_IB_DISABLE=1` is set in the batch script)
- Adapters land at `/mnt/data/nebius-demo/checkpoints/helios-lora`

### 6. Capture evidence for the interview

Keep screenshots / notes of:

- `sinfo` / `squeue` during the job
- Training log with loss decreasing
- Nebius console GPU utilization on both H100s
- `ls -lh /mnt/data/nebius-demo/checkpoints/helios-lora`

## How the training job works (explain this)

1. Slurm allocates `worker-0` and `worker-1`.
2. `srun` starts one `torchrun` per node.
3. Rank 0 listens on Ethernet. Rank 1 joins.
4. Each rank loads Qwen2.5-7B, freezes base weights, attaches LoRA.
5. Each rank trains on a shard of `workloads/data/helios_faq.jsonl`.
6. Gradients average over TCP (NCCL Socket).
7. Rank 0 writes adapters to `/mnt/data`.

If training hangs at NCCL init, the IB disable flags are missing or `NCCL_SOCKET_IFNAME` does not match the worker NIC. Run `ip -br addr` on a worker and set the interface explicitly.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `gpu_cluster must set either id or infiniband_fabric` | You still have `gpu_cluster = { infiniband_fabric = "" }` |
| Node group create fails on GPU cluster | Fabric/id still set; preset cannot join a GPU cluster |
| `yq: command not found` during apply | Install yq on the machine running Terraform |
| Public o11y / missing `soperator-telemetry` profile | `public_o11y_enabled` is still true |
| NCCL IB health check fails | `active_checks_scope` is not `essential` |
| Pods pending on GPU taint | Expected for non-Slurm pods; do not fight it |
| CUDA OOM | Lower `PER_DEVICE_BATCH` in `train.sbatch` |
| Both ranks are rank 0 | `torchrun` `--nnodes` / `--rdzv_endpoint` mismatch |
| Jail changes missing on a worker | Install into `/mnt/data` or jail root, never node-local `/tmp` only |
