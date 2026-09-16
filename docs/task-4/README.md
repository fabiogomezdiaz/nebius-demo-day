# Task 4 — utilize more than 80% of the GPUs

**Partial.** Extra mile.

Assignment: utilize **more than 80% of the GPUs**, using Nebius console dashboards. Live: [GPU metrics](https://console.nebius.com/project-e00dqh87pr00x1qed0hwcy/mk8s/mk8scluster-e00v96aa42fmcr2smq/monitoring?monitoring_dashboard=gpu-metrics&monitoring_mk8s_node_group_id=all&monitoring_instance_id=all).

Parked vLLM is ~0% SM and ~70 GiB HBM. This task is the **load**, not a third cluster mode. Serve both models first (`./task-3/01-serve.sh`), then hit **both** URLs so green and yellow VMs generate at once.

```bash
./task-3/01-serve.sh       # one vLLM per H100
./task-4/01-load.sh        # 100 Dolly prompts, forever, Ctrl-C when the screenshot is done
```

`.` = `qwen25-7b` on `quen-qwen25.fabiogomezdiaz.app`.  
`+` = `dolly` on `quen-lora-dolly.fabiogomezdiaz.app`.

The load script walks `task-3/prompts.jsonl` (100 held-out Dolly rows) and starts over when it hits the end. Ctrl-C is the only stop.

Turn it up if SM is still low:

```bash
CONCURRENCY=8 MAX_TOKENS=512 ./task-4/01-load.sh
```

Without DNS, port-forward both services and pass `BASE_URL` / `DOLLY_URL` (same vars as `./task-3/03-compare.sh`).

## What job 73 already showed (training)

| Chart | Result |
| --- | --- |
| GPU utilization (SM) | **~100%** on both H100s |
| Memory / HBM | **~55–70%** (~50 GB of ~80 GB) |
| Duration | ~35 s of train — a spike, not a plateau |

Screenshots: [../task-1/static/evidence/](../task-1/static/evidence/). Write-up: [../task-1/report.md](../task-1/report.md).

A longer train (more epochs / larger batch) would make the >80% SM window easier to screenshot. Filling 80% of 80 GB HBM needs a bigger batch or model; 7B LoRA does not. Serve load fills HBM (KV cache) and can raise SM while tokens are in flight.

See [../overview/status.md](../overview/status.md). Compare answers: [../task-3/](../task-3/).
