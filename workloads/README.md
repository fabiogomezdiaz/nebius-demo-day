# Workloads

These scripts run **inside the Slurm jail** on the login node, after `scripts/04-sync_workloads.sh`. Training is done (job 66). Inference / base-vs-LoRA compare are **not** in this folder yet — [00-status.md](../docs/00-status.md).

| File | Role |
| --- | --- |
| `setup_env.sh` | Shared venv on `/mnt/data` so both workers see the same Python |
| `fetch_dolly.py` | Download Dolly-15k onto this workstation (cache + JSONL preview) |
| `data/dolly-preview.jsonl` | First 20 Dolly rows, converted to chat `messages` |
| `data/helios_faq.jsonl` | Optional synthetic fallback (`TRAIN_DATA=...`) |
| `train.py` / `train.sbatch` | 2-node LoRA SFT; default source is Hugging Face Dolly. Beginner walkthrough: [02-how-train-py-works.md](../docs/02-how-train-py-works.md) |

On the workstation, inspect Dolly with:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install "datasets==3.5.0"
python workloads/fetch_dolly.py
```

That caches the Hub files under `workloads/hf_cache/` and writes `workloads/data/dolly-preview.jsonl`. On the cluster, `train.sbatch` sets `HF_HOME=/mnt/data/nebius-demo/hf_cache` and `train.py` downloads the same `train[:1500]` slice on first run.

To train the old Helios JSONL instead: `export TRAIN_DATA=/mnt/data/nebius-demo/workloads/data/helios_faq.jsonl`.

Environment variables used by the batch script are documented at the top of `train.sbatch`.
