# GitOps inventory

Operators are applied with Terraform using a **local kubeconfig** (`terraform/kubeconfig`, gitignored). Flux is Soperator’s installer only.

| Stack | Path | What it deploys |
| --- | --- | --- |
| Cluster | `terraform/infra` | MK8s, node groups, filestore |
| Platform | `terraform/platform` | Flux (Soperator installer), Soperator/Slurm, GPU Operator |

Training files live in `task-1/` and are copied onto the jail with `./scripts/04-sync_task-1.sh`, then submitted with `sbatch` after `./scripts/05-login.sh`.
