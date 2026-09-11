# GitOps inventory

Operators and CRs are applied with Terraform using a **local kubeconfig** (`terraform/kubeconfig`, gitignored). ArgoCD is installed as the GitOps control plane; AppProjects `platform` and `workloads` exist in-cluster.

| Stack | Path | What it deploys |
| --- | --- | --- |
| Cluster | `terraform/infra` | MK8s, node groups, filestore |
| Platform | `terraform/platform` | Flux (Soperator installer), Soperator/Slurm, GPU Operator, Training Operator, ArgoCD |
| Workloads | `terraform/workloads` | `login.sh`, namespaces, ConfigMap, optional NCCL MPIJob CR |

YAML for CRs lives here so Terraform can `yamldecode` it. The same files can be applied with `kubectl apply -k gitops/workloads` if needed.

- `gitops/workloads/configmap.yaml`
- `gitops/workloads/mpijob.yaml`

## Order

1. `./scripts/02-apply_infra.sh` (writes `terraform/kubeconfig`).
2. `./scripts/03-apply_platform.sh` — platform then workloads (MPIJob off).
3. `./scripts/04-scale_slurm_gpu_workers.sh 0` then `terraform apply -var=enable_nccl_mpijob=true` in `workloads`.
4. Restore workers (`04 … 2`) before `sbatch`.

NCCL uses Ethernet (`NCCL_IB_DISABLE=1`). There is no InfiniBand HCA and no Network Operator.
