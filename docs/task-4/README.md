# Task 4 — utilize more than 80% of the GPUs

**Partial.** Extra mile.

Assignment: utilize **more than 80% of the GPUs**, using Nebius console dashboards.

## What job 73 showed

| Chart | Result |
| --- | --- |
| GPU utilization (SM) | **~100%** on both H100s |
| Memory / HBM | **~55–70%** (~50 GB of ~80 GB) |
| Duration | ~35 s of train — a spike, not a plateau |

Screenshots: [../task-1/static/evidence/](../task-1/static/evidence/). Write-up: [../task-1/report.md](../task-1/report.md).

A longer run (more epochs / larger batch) would make the >80% SM window easier to screenshot. Filling 80% of 80 GB HBM needs a bigger batch or model; 7B LoRA does not.

See [../overview/status.md](../overview/status.md).
