# Terraform projects

Three applies, in order. Projects live **flat** under `terraform/`. Kubernetes/Helm in the last two use a **local kubeconfig** at `terraform/kubeconfig` (gitignored, not Vault). The infra stack writes that file via `nebius mk8s cluster get-credentials`.

State is **local** (`terraform/infra/terraform.tfstate`, gitignored). The Nebius provider authenticates with your CLI IAM token (`nebius iam get-access-token`). There is no Terraform service account or Object Storage backend.

1. **`terraform/infra/`** — Nebius cloud only: MK8s, GPU/CPU node groups, filestore. No Helm/Kubernetes providers.
2. **`terraform/platform/`** — Cluster operators: Flux (Soperator's installer), Soperator/Slurm, NVIDIA GPU Operator.
3. **`terraform/workloads/`** — `login.sh` SSH helper.

Soperator modules are fetched from GitHub at `soperator-v4.1.8-1`.

**Flux:** Soperator deploys its operator and `SlurmCluster` as Flux HelmReleases. That is not optional.

**o11y:** Nebius public observability (hosted metrics/logs). This environment sets `public_o11y_enabled = false`, so the o11y Terraform module is not applied. Slurm still gets that flag via remote state.

**Backups:** jail backups are `force_disable`. The backup operator/bucket modules are not applied.

Destroy **workloads → platform → infra** so Kubernetes cleanup runs while the cluster still exists. `06-destroy_platform.sh` runs `terraform destroy` and then `terraform/platform/scripts/platform_k8s_wipe.sh`, because Helm `resource-policy: keep` leaves Flux HelmReleases, namespaces, and CR finalizers that Terraform does not delete. Infra (MK8s, filestore) stays until you run `07`. Each destroy script prints a plan and waits for `yes` (no `-auto-approve`):

```bash
./scripts/05-destroy_workloads.sh
./scripts/06-destroy_platform.sh
./scripts/07-destroy_infra.sh
```

## infra files

| File | Concern |
| --- | --- |
| `versions.tf` | Terraform and provider version pins |
| `providers.tf` | Nebius / units / string-functions providers |
| `01-locals.tf` | Naming and resource lookups |
| `02-filestore.tf` | Jail, spool, `/mnt/data` |
| `03-k8s.tf` | MK8s and node groups |
| `04-outputs.tf` | Remote-state payload for platform (`soperator` object) |
| `05-kubeconfig.tf` | Writes `terraform/kubeconfig` |
| `cleanup.tf` | Leftover `pvc-*` disks on infra destroy |

## platform files

| File | Concern |
| --- | --- |
| `versions.tf` | Terraform and provider version pins |
| `providers.tf` | Kubernetes / Helm via local kubeconfig |
| `variables.tf` | Kubeconfig and SSH public key paths |
| `remote-state.tf` | Infra outputs (`soperator` object) |
| `01-fluxcd.tf` | Flux — Soperator's installer |
| `02-gpu-operator.tf` | NVIDIA GPU Operator (`driver.enabled=false`) |
| `03-soperator.tf` | Soperator / Slurm |
| `04-soperator-flux-overlay.tf` | Skip bootstrap activechecks that hang this lab |
| `cleanup.tf` | Destroy-time login/Kruise hooks and Flux leftover wipe |

## Apply

```bash
./scripts/01-seed_tfvars.sh
./scripts/02-apply_infra.sh                 # cluster + kubeconfig
./scripts/03-apply_platform.sh              # platform (includes Soperator) + login.sh
```

SSH helper after workloads apply: `terraform/workloads/login.sh -k <ssh-private-key>`.

InfiniBand skip: [docs/terraform-infiniband-changes.md](../docs/terraform-infiniband-changes.md).
