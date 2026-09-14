# Task 1 artifacts (copied off the jail)

Pulled from `root@login-0:/mnt/data/nebius-demo` plus `/etc/slurm/gres.conf`.

| Path | What |
| --- | --- |
| [`outputs/train-73.log`](outputs/train-73.log) / [`.err`](outputs/train-73.err) | Successful Dolly LoRA job |
| [`outputs/train-71.log`](outputs/train-71.log) / [`.err`](outputs/train-71.err) | Failed `SFTConfig(args=)` job |
| [`outputs/`](outputs/) | Earlier jobs 59, 60, 66 (Helios), 72 |
| [`checkpoints/dolly-lora/`](checkpoints/dolly-lora/) | Final LoRA adapters + tokenizer (~154 MB `adapter_model.safetensors`) |
| [`checkpoints/dolly-lora/checkpoint-4/trainer_state.json`](checkpoints/dolly-lora/checkpoint-4/trainer_state.json) | Step/loss record |
| [`gres.conf`](gres.conf) | Live Slurm GRES map from the jail |

**Not copied** (large or not needed for the talk):

- `checkpoints/helios-lora` (~3.9 GB, earlier run)
- `checkpoint-4/optimizer.pt` (~309 MB)
- `hf_cache/`, `venv/`

`outputs/` and `checkpoints/` are gitignored. Re-sync from the jail if you need them again.

```bash
KEY="${SSH_PRIVATE_KEY:-$HOME/.ssh/id_rsa}"
HOST="$(./task-1/login_host.sh)"
rsync -az -e "ssh -i ${KEY}" \
  "root@${HOST}:/mnt/data/nebius-demo/outputs/" \
  docs/task-1/artifacts/outputs/
```
