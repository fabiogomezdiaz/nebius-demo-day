# Scripts (run in this order)

| # | Script | When |
| --- | --- | --- |
| 00 | `00-install_prereqs.sh` | Install Terraform, Nebius CLI, kubectl, Helm, jq, yq, coreutils (skips if present) |
| 01 | `01-seed_envrc.sh` | Write tenant/project into `.envrc` and SSH pubkey into `terraform.tfvars` |
| 02 | `02-apply_infra.sh` | `source .envrc && terraform init && terraform apply` in `terraform/infra` |
| 03 | `03-apply_platform.sh` | Apply `platform` (Flux + Soperator + GPU Operator + ArgoCD) then `workloads` (`login.sh`, MPIJob off) |
| 04 | `04-scale_slurm_gpu_workers.sh` | `0` to free GPUs; then apply workloads with `enable_nccl_mpijob=true` |
| 05 | `05-sync_workloads.sh` | Copy `workloads/` onto the jail (`/mnt/data`) |
| 06 | `06-tunnel_inference.sh` | Port-forward vLLM after Tasks 2–3 serve jobs |
| 07 | `07-destroy_workloads.sh` | `terraform destroy` in `terraform/workloads` (plan + yes) |
| 08 | `08-destroy_platform.sh` | `terraform destroy` in `terraform/platform`, then wipe Flux/Soperator leftovers on the cluster (plan + yes). Does not destroy MK8s. |
| 09 | `09-destroy_infra.sh` | `terraform destroy` in `terraform/infra` (plan + yes) |

Destroy order is **workloads → platform → infra** so Kubernetes cleanup still has a cluster. Destroy scripts skip `terraform destroy` when state is empty, then (for platform) run an idempotent cluster wipe that exits immediately if nothing is left. None of the destroy scripts pass `-auto-approve`.

Task 1 training is `sbatch` on the login node, not a script here.
