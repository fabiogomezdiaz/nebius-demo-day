# Scripts (run in this order)

| # | Script | When |
| --- | --- | --- |
| 00 | `00-install_prereqs.sh` | Install Terraform, Nebius CLI, kubectl, Helm, jq, yq, coreutils (skips if present) |
| 01 | `01-seed_tfvars.sh` | Write tenant, project, region, subnet, kubeconfig path, and SSH pubkey path into `terraform.tfvars` |
| 02 | `02-apply_infra.sh` | `terraform init && terraform apply` in `terraform/infra` |
| 03 | `03-apply_platform.sh` | Apply `platform` (Flux + Soperator + GPU Operator) |
| 04 | `04-sync_workloads.sh` | Copy `workloads/` onto the jail (`/mnt/data`) |
| 05 | `05-login.sh` | SSH to the Slurm login node |
| 06 | `06-destroy_platform.sh` | `terraform destroy` in `terraform/platform`, then wipe Flux/Soperator leftovers on the cluster (plan + yes). Does not destroy MK8s. |
| 07 | `07-destroy_infra.sh` | `terraform destroy` in `terraform/infra` (plan + yes) |

`04` and `05` default to `~/.ssh/id_rsa` (override with argument 1 or `SSH_PRIVATE_KEY`) and resolve the login IP from `soperator-login-svc` (`login_host.sh`). Destroy order is **platform → infra** so Kubernetes cleanup still has a cluster. Destroy scripts skip `terraform destroy` when state is empty, then (for platform) run an idempotent cluster wipe that exits immediately if nothing is left. None of the destroy scripts pass `-auto-approve`.

Task 1 training is `sbatch` on the login node, not a script here.
