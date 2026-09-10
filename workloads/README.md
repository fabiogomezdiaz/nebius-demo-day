# Workloads

These scripts run **inside the Slurm jail** on the login node, after `scripts/sync_workloads.sh`.

| File | Role |
| --- | --- |
| `setup_env.sh` | Shared conda env on `/mnt/data` so both workers see the same Python |
| `data/helios_faq.jsonl` | Tiny synthetic domain dataset |
| `data/eval_prompts.jsonl` | Comparison prompts |
| `train.py` / `train.sbatch` | 2-node LoRA SFT over Ethernet NCCL |
| `serve_base.sbatch` / `serve_ft.sbatch` | vLLM, one GPU each |
| `compare.py` | Side-by-side generations |
| `loadgen.py` | Concurrent requests to keep both GPUs busy |

Environment variables used by the batch scripts are documented at the top of each `.sbatch` file.
