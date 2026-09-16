# Task 1 — distributed training on Soperator

**Done.** 2-node LoRA SFT of Qwen2.5-7B-Instruct on Dolly, Ethernet NCCL, no InfiniBand.

Talk track: [report.md](report.md) (job 73 logs + GPU screenshots).

| Doc | What |
| --- | --- |
| [report.md](report.md) | Presentation write-up |
| [training.md](training.md) | Runbook (`00` → `sbatch`) |
| [gotchas.md](gotchas.md) | GRES, NCCL, sbatch failures |
| [architecture.md](architecture.md) | Infra / platform / training diagram |
| [how-train-py-works.md](how-train-py-works.md) | What `train.py` does |
| [demo-script.md](demo-script.md) | Live demo narrative |
| [terraform-infiniband.md](terraform-infiniband.md) | 1-GPU Ethernet Terraform overlay |
| [diagrams/](diagrams/) | Eraser source |
| [static/](static/) | PNGs + [evidence](static/evidence/) screenshots |

Assignment / status: [../overview/](../overview/).
