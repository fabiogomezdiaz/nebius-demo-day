# Task 3 — base vs trained compare

**Not done.** Extra mile.

Assignment: run the **original (untrained)** model and **compare** results to the fine-tuned adapters.

## What exists

- Base: `Qwen/Qwen2.5-7B-Instruct`
- Adapters: `/mnt/data/nebius-demo/checkpoints/dolly-lora` (job 73)

- Base is already served as `qwen25-7b` next to LoRA `dolly` (task 2). Nothing has queried them side by side yet.

See [../overview/status.md](../overview/status.md). Training path: [../task-1/](../task-1/).
