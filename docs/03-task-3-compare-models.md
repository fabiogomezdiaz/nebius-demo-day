# Compare base vs fine-tuned

Run the **original** Qwen2.5-7B-Instruct and the **LoRA fine-tuned** model, and show that the fine-tuned model learned Helios Robotics facts the base model does not have.

## Layout

Two vLLM servers, one GPU each:

| Job | GPU | Port | Model id |
| --- | --- | --- | --- |
| `serve_base.sbatch` | worker A | 8000 | `Qwen/Qwen2.5-7B-Instruct` |
| `serve_ft.sbatch` | worker B | 8001 | `helios` (base + LoRA) |

`compare.py` sends the **same prompts** to both and writes a side-by-side JSON and markdown table.

## Serve the base model

```bash
sbatch workloads/serve_base.sbatch
squeue   # two jobs, two nodes, two GPUs
```

## Run the comparison

The login node can reach workers on the cluster network. `compare.py` reads host files written by the serve jobs:

```bash
python /mnt/data/nebius-demo/workloads/compare.py \
  --prompts /mnt/data/nebius-demo/workloads/data/eval_prompts.jsonl \
  --out /mnt/data/nebius-demo/outputs/comparison.md
```

Keep `comparison.md` as the comparison artifact.

## Prompts to show

1. **In-domain fact** — “Who is the CEO of Helios Robotics?”  
   Base: refuses or invents. Fine-tuned: Mira Chen.
2. **In-domain procedure** — “What is the cooling loop spec for the HX-9 arm?”  
   Fine-tuned quotes the FAQ numbers.
3. **Out-of-domain control** — “What is the capital of France?”  
   Both should still answer Paris (the base model is not destroyed).
4. **Refusal / safety** — a generic harmless question both handle similarly.

This is a **qualitative domain-adaptation** demo on a small dataset, not a benchmark claim.

## Optional numeric check

`compare.py --perplexity` runs a small perplexity pass on the FAQ answers. Lower perplexity on the fine-tuned model is expected. Treat it as supporting evidence, not the headline.
