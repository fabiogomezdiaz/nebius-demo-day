# Task 3 — Compare base vs fine-tuned

## Goal

Run the **original** Qwen2.5-7B-Instruct and the **LoRA fine-tuned** model, then show that the fine-tuned model learned Helios Robotics facts the base model does not have.

## Shape of the demo

Two vLLM servers, one GPU each:

| Job | GPU | Port | Model id |
| --- | --- | --- | --- |
| `serve_base.sbatch` | worker A | 8000 | `Qwen/Qwen2.5-7B-Instruct` |
| `serve_ft.sbatch` | worker B | 8001 | `helios` (base + LoRA) |

Then `compare.py` sends the **same prompts** to both and writes a side-by-side JSON + markdown table.

## Steps

### 1. Serve the base model

```bash
sbatch workloads/serve_base.sbatch
squeue   # two jobs, two nodes, two GPUs
```

### 2. Run the comparison from the login node

The login node can reach workers on the cluster network. `compare.py` reads host files written by the serve jobs:

```bash
python /mnt/data/nebius-demo/workloads/compare.py \
  --prompts /mnt/data/nebius-demo/workloads/data/eval_prompts.jsonl \
  --out /mnt/data/nebius-demo/outputs/comparison.md
```

Copy `comparison.md` into git (it is the artifact you attach in the submission email).

### 3. What to show on the call

Use 3–4 prompts:

1. **In-domain fact** — "Who is the CEO of Helios Robotics?"  
   Base: refuses / invents. Fine-tuned: Mira Chen.
2. **In-domain procedure** — "What is the cooling loop spec for the HX-9 arm?"  
   Fine-tuned quotes the FAQ numbers.
3. **Out-of-domain control** — "What is the capital of France?"  
   Both should still answer Paris. Proves we did not wreck the base model.
4. **Refusal / safety** — a generic harmless question both handle similarly.

Do not claim SOTA metrics. This is a **qualitative domain-adaptation demo** with a tiny dataset, which is the honest story.

## Optional numeric check

`compare.py --perplexity` runs a tiny perplexity pass on the FAQ answers. Lower perplexity on the fine-tuned model is expected. Treat it as supporting evidence, not the headline.
