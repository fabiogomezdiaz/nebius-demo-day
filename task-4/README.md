# Task 4 — keep both GPUs busy

| File | Role |
| --- | --- |
| `01-load.sh` | Forever-loop of 100 Dolly prompts on **both** task-3 URLs (original + LoRA) |

Needs two vLLMs up: `./task-3/01-serve.sh`. Then:

```bash
./task-4/01-load.sh
CONCURRENCY=8 MAX_TOKENS=512 ./task-4/01-load.sh
```

`.` is original (`qwen25-7b`), `+` is LoRA (`dolly`). Cycles `task-3/prompts.jsonl` until Ctrl-C. Screenshot the Nebius GPU tab while it runs.

Runbook: [../docs/task-4/README.md](../docs/task-4/README.md).
