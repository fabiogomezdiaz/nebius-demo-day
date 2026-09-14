# Task 1 — training files

LoRA SFT job files. Sync onto the jail with `scripts/04-sync_task-1.sh`, then `sbatch` from the login node. Training is done (job 73). Inference / base-vs-LoRA compare live under [docs/task-2](../docs/task-2/) and [docs/task-3](../docs/task-3/).

| File | Role |
| --- | --- |
| `setup_env.sh` | Shared venv on `/mnt/data` so both workers see the same Python |
| `fetch_dolly.py` | Download Dolly-15k onto this workstation (cache + JSONL preview) |
| `data/dolly-preview.jsonl` | First 20 Dolly rows, converted to chat `messages` |
| `train.py` / `train.sbatch` | 2-node LoRA SFT on Hugging Face Dolly. Beginner walkthrough: [how-train-py-works.md](../docs/task-1/how-train-py-works.md) |

On the workstation, inspect Dolly with:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install "datasets==3.5.0"
python task-1/fetch_dolly.py
```

That caches the Hub files under `task-1/hf_cache/` and writes `task-1/data/dolly-preview.jsonl`. On the cluster, `train.sbatch` sets `HF_HOME=/mnt/data/nebius-demo/hf_cache` and `train.py` always downloads the same `train[:1500]` Dolly slice on first run.

Environment variables used by the batch script are documented at the top of `train.sbatch`.
