# Workloads

These scripts run **inside the Slurm jail** on the login node, after `scripts/04-sync_workloads.sh`. Training is done (job 66). Inference / base-vs-LoRA compare are **not** in this folder yet — [00-status.md](../docs/00-status.md).

| File | Role |
| --- | --- |
| `setup_env.sh` | Shared venv on `/mnt/data` so both workers see the same Python |
| `data/helios_faq.jsonl` | Tiny synthetic domain dataset |
| `train.py` / `train.sbatch` | 2-node LoRA SFT over Ethernet NCCL |

Environment variables used by the batch script are documented at the top of `train.sbatch`.
