# Nebius Demo Day — Soperator on 2×H100 without InfiniBand

Deploy [Soperator](https://github.com/nebius/soperator) from the official [solutions library](https://github.com/nebius/nebius-solutions-library), install the Nebius marketplace NVIDIA GPU Operator, then fine-tune Qwen2.5-7B-Instruct with LoRA across two Ethernet H100s.

**Pinned recipe:** [`soperator-v4.1.8-1`](https://github.com/nebius/nebius-solutions-library/releases/tag/soperator-v4.1.8-1) (not `main`).

Assignment brief: [docs/00-assignment.md](docs/00-assignment.md).  
Status (done vs missing): [docs/00-status.md](docs/00-status.md).  
Glossary: [docs/00-glossary.md](docs/00-glossary.md).  
Task 1 gotchas: [docs/01-task-1-gotchas.md](docs/01-task-1-gotchas.md).

## Scope

[`k8s-training`](https://github.com/nebius/nebius-solutions-library/tree/main/k8s-training) targets 8×H100 plus InfiniBand. This lab is **2×1×H100, no InfiniBand**, and uses **Soperator**.

| Layer | Upstream | Overlay |
| --- | --- | --- |
| Cluster + Slurm | `soperator/` Terraform via `git::` | tfvars: 1gpu preset, sentinel `gpu_cluster.id`, CPU table |
| GPU Operator | Marketplace OCI chart | Helm in `terraform/platform`, `driver.enabled=false` |
| Training | Slurm on that cluster | `workloads/train.sbatch` |

```mermaid
flowchart LR
  subgraph infra [Nebius]
    TF[infra Terraform]
  end
  subgraph platform [platform Terraform]
    FLUX[Flux for Soperator]
    SOP[Soperator / Slurm]
    GOP[GPU Operator]
  end
  subgraph demo [Task 1]
    TRAIN[torchrun LoRA]
  end
  TF --> FLUX
  FLUX --> SOP
  GOP --> SOP
  SOP --> TRAIN
```

## Runbook

1. `./scripts/00-install_prereqs.sh` (Terraform, Nebius CLI, kubectl, Helm, jq, yq, coreutils; skips tools already on PATH).
2. `./scripts/01-seed_tfvars.sh` — tenant/project/region/subnet and SSH public key path into `terraform.tfvars`.
3. `./scripts/02-apply_infra.sh` — `terraform init && terraform apply` in `terraform/infra`. Writes `terraform/kubeconfig`.
4. `./scripts/03-apply_platform.sh` — platform (Flux, Soperator, GPU Operator).
5. `./scripts/04-sync_workloads.sh`
6. `./scripts/05-login.sh` then `sinfo`.
7. On login: `bash /mnt/data/nebius-demo/workloads/setup_env.sh`.
8. `sbatch /mnt/data/nebius-demo/workloads/train.sbatch`.
9. Confirm `world_size=2`, adapters at `/mnt/data/nebius-demo/checkpoints/helios-lora`, both GPUs busy.

Detail: [docs/01-task-1-soperator-training.md](docs/01-task-1-soperator-training.md).  
InfiniBand Terraform notes: [docs/terraform-infiniband-changes.md](docs/terraform-infiniband-changes.md).

## Constraints

- GPU limit = **2×H100**, **1×H100 per node**
- Single MK8s cluster
- Single-GPU H100 preset **does not support InfiniBand**
- `public_o11y_enabled = false`
- Do not share one filesystem between two jails
- CPU nodesets sized to **6 nodes / 52 vCPU** in this lab (assignment table is 8 nodes / 64 vCPU including Accounting + NFS — those two are off; see [00-status.md](docs/00-status.md))
- Retain the environment for the duration of the demo

## Repository layout

```
docs/            # assignment, status, glossary, runbooks, architecture
gitops/          # notes; operators are Terraform in terraform/platform
terraform/       # infra (cloud) + platform (operators)
scripts/         # 00 prereqs → 04 sync → 05 login → 06–07 destroy
workloads/       # train.sbatch / train.py / setup_env.sh
presentation/    # PowerPoint source + generated deck
```

Architecture: [docs/architecture-task-1.md](docs/architecture-task-1.md).  
Walkthrough: [docs/demo-script.md](docs/demo-script.md).  
Slides: [presentation/Nebius-Demo-Day.pptx](presentation/Nebius-Demo-Day.pptx).

## Overlay notes

Terraform overlay: `terraform/infra/terraform.tfvars`.

- Soperator `4.1.8` on 2×`1gpu-16vcpu-200gb` without attaching InfiniBand; 2-node LoRA SFT.
- Stock recipe assumes an IB GPU cluster; empty `infiniband_fabric` fails validation; NCCL is forced onto Ethernet.

## License

MIT. Soperator module bodies stay in [nebius/nebius-solutions-library](https://github.com/nebius/nebius-solutions-library) and are fetched at tag `soperator-v4.1.8-1`. This repository keeps an infra cloud stack and a platform operator stack (including Soperator/Flux). Kubeconfig is local (`terraform/kubeconfig`), not Vault.
