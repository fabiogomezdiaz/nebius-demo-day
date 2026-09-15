# Task 1 — distributed training on Soperator

Self-contained runbook for Task 1: cluster + Slurm + LoRA SFT. Training is done (job 73). Inference lives under [../task-2](../task-2/). Compare: [../docs/task-3](../docs/task-3/).

From the repo root:

```bash
./task-1/00-install_prereqs.sh
./task-1/01-seed_tfvars.sh
./task-1/02-apply_infra.sh
./task-1/03-apply_platform.sh
./task-1/04-sync.sh
./task-1/05-login.sh   # then sinfo / sbatch on login
```

Destroy after the interview, **platform then infra**:

```bash
./task-1/06-destroy_platform.sh
./task-1/07-destroy_infra.sh
```

| File | Role |
| --- | --- |
| `00-install_prereqs.sh` | Terraform, Nebius CLI, kubectl, Helm, jq, yq, coreutils |
| `01-seed_tfvars.sh` | Tenant / project / region / subnet / SSH pubkey into tfvars |
| `02-apply_infra.sh` | MK8s, node groups, filestore, kubeconfig |
| `03-apply_platform.sh` | Flux, Soperator, GPU Operator; restores 2 workers (drops Task 2 vLLM) |
| `04-sync.sh` | Copy job files onto `/mnt/data/nebius-demo/task-1/` (skips laptop scripts and hf_cache) |
| `05-login.sh` | SSH to the Slurm login LoadBalancer |
| `06-destroy_platform.sh` | Tear down operators; keep MK8s |
| `07-destroy_infra.sh` | Tear down MK8s and filestore |
| `login_host.sh` | Print `soperator-login-svc` IP |
| `retry.sh` | IAM-token / CLI retry helper |
| `setup_env.sh` | Shared venv on `/mnt/data` (run on login) |
| `fetch_dolly.py` | Download Dolly-15k onto this workstation |
| `data/dolly-preview.jsonl` | First 20 Dolly rows as chat `messages` |
| `train.py` / `train.sbatch` | 2-node LoRA SFT. Walkthrough: [how-train-py-works.md](../docs/task-1/how-train-py-works.md) |

Docs: [../docs/task-1/](../docs/task-1/).

On the workstation, inspect Dolly with:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install "datasets==3.5.0"
python task-1/fetch_dolly.py
```

That caches Hub files under `task-1/hf_cache/` and writes `task-1/data/dolly-preview.jsonl`. On the cluster, `train.sbatch` sets `HF_HOME=/mnt/data/nebius-demo/hf_cache` and `train.py` downloads the same `train[:1500]` Dolly slice on first run.

`05-login.sh` defaults to `~/.ssh/id_rsa` (or `SSH_PRIVATE_KEY`). Destroy scripts print a plan and wait for `yes`.
