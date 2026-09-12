# Overlay vs the stock Soperator recipe

Pinned release: **`soperator-v4.1.8-1`** (operator version `4.1.8`). Do not use `main`.

Catalog of everything that broke and why: [gotchas.md](gotchas.md).

The stock recipe is in [nebius/nebius-solutions-library](https://github.com/nebius/nebius-solutions-library/tree/soperator-v4.1.8-1/soperator). This repository does not fork or vendor the modules. `terraform init` fetches them with `git::` at that tag.

Two Terraform projects:

| Project | Role |
| --- | --- |
| `terraform/infra` | Cloud overlay and tfvars (MK8s, disks, node groups) |
| `terraform/platform` | Soperator/Flux and other cluster operators |

## InfiniBand and the 1-GPU preset

`1gpu-16vcpu-200gb` on `gpu-h100-sxm` is **not** in Nebius’s GPU-cluster-compatible preset list. Only `8gpu-128vcpu-1600gb` can join an InfiniBand GPU cluster.

Configurations that fail:

1. Example `gpu_cluster = { infiniband_fabric = "" }`. Validation requires a non-empty `id` or `infiniband_fabric` whenever the object is set.
2. A real fabric name. Terraform creates `nebius_compute_v1_gpu_cluster`. The API rejects attaching `1gpu-16vcpu-200gb`.
3. `gpu_cluster = null`. Correct semantically, but stock `gpu_fabric_validation.tf` requires `id` or `infiniband_fabric` on **every** GPU preset, including this 1-GPU one.
4. InfiniBand-oriented Network Operator / NCCL IB health checks. This preset does not expose an IB NIC.

## Overlay for Ethernet-only workers

In `slurm_nodeset_workers`:

```hcl
resource = {
  platform = "gpu-h100-sxm"
  preset   = "1gpu-16vcpu-200gb"
}
size = 2
autoscaling = {
  enabled  = false
  min_size = 2
}
gpu_cluster = {
  id = "ethernet-not-attached"
}
```

In the recipe (`soperator/modules/k8s/k8s_ng_workers_v2.tf`):

- `gpu_cluster.id` is set, so fabric validation passes and `local.gpu_clusters_v2` stays empty (a cluster is created only when `id` is empty and `infiniband_fabric` is set).
- `1gpu-16vcpu-200gb` has `gpu_cluster_compatible = false`, so `template.gpu_cluster` on the MK8s node group remains `null`. The sentinel id is never attached.
- `use_preinstalled_gpu_drivers = true` skips installing GPU/Network operators from the Soperator chart (drivers come from the Nebius GPU image). This overlay installs GPU Operator from the marketplace in `terraform/platform` with `driver.enabled=false`. Network Operator is omitted: this preset has no InfiniBand HCA.
- Stock `gres_config_by_platform` is the 8-GPU H100 layout (`Cores=0-31`, eight `/dev/nvidiaN` lines). On `1gpu-16vcpu-200gb` that makes `slurmctld` exit with `Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)`. Infra overrides GRES to one GPU: `/dev/nvidia0`, `Cores=0-15`. See [GRES](#gres-gresconf).

## GRES (`gres.conf`)

Explain this if asked why the controller CrashLoop’d, or why the overlay is not “just tfvars.”

**GRES** is Slurm’s **Generic RESource** map. Kubernetes learns GPUs from the device plugin (`nvidia.com/gpu`). Slurm does not: `slurmctld` only believes `gres.conf` — device file, GPU type, and which CPU IDs may use that GPU. Soperator writes that file from Terraform `worker_nodesets[].gres_config`. A map that lists more cores or `/dev/nvidiaN` files than the node has is fatal.

The solutions library looks up GRES by **platform** (`gpu-h100-sxm`), not by **preset**. That map is the 8-GPU NVLink node:

```text
File=/dev/nvidia4 Cores=0-31 Links=-1,1,1,1,1,1,1,1
...
File=/dev/nvidia3 Cores=32-63 ...
```

This lab’s workers are `1gpu-16vcpu-200gb`: 16 logical CPUs, one GPU at `/dev/nvidia0`. `slurm.conf` already has the right node line (`CPUs=16`, `Gres=gpu:nvidia_h100_80gb_hbm3:1`). `gres.conf` did not. `slurmctld` then fatals:

```text
fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)
```

`controller-0` CrashLoopBackOff; workers sit at `Init:3/4` pinging a DOWN controller.

Infra overlay in `terraform/infra/04-outputs.tf`: when the preset reports `gpus == 1`, replace the stock list with:

```text
AutoDetect=off Name=gpu Type=nvidia_h100_80gb_hbm3 File=/dev/nvidia0 Cores=0-15 Links=-1 Flags=nvidia_gpu_env
```

Apply **infra** (updates the `soperator` output) then **platform** (Flux/Helm rewrite `gres.conf`). Kubernetes GPUs (`nvidia.com/gpu` via GPU Operator) are a separate path; this bug is only Slurm’s scheduler config.

On 8×H100 you would drop this override and use the stock 8-device map (and InfiniBand).

## Configuration vs stock example

| Setting | Stock example | This environment | Reason |
| --- | --- | --- | --- |
| `production` | `true` | `false` | Sandbox is not Soperator Pro; avoids IAM merge-request validation |
| `public_o11y_enabled` | `true` | `false` | Known recipe issue; public telemetry is disabled |
| `active_checks_scope` | empty / prod | `"essential"` | Skip long NCCL-over-IB checks that cannot pass. Still not enough: `ensure-healthy-nodes` and `wait-for-soperatorchecks-srun-ready` stay `runAfterCreation=true`, and the slurm module waits 240m for that HelmRelease. Platform patches `soperator-fluxcd-values` to turn those two off so `03-apply_platform.sh` can finish. |
| `slurm_shared_memory_size_gibibytes` | `1024` | `64` | Worker RAM is 200 GiB, not 1600 GiB |
| System nodeset | min 3 / max 9 | min 4 / max 4 | Cap at 32 vCPU |
| Login | 32vcpu-128gb × 2 | 16vcpu-64gb × 1 | Capacity table |
| Controller | 16vcpu-64gb | 4vcpu-16gb | Capacity table |
| Accounting | 8vcpu-32gb | disabled | Not required by demo tasks |
| NFS | 32vcpu-128gb | disabled | Demo I/O is filestore jail + `/mnt/data` |
| Jail | existing ID | new `spec` | Do not reuse another jail’s filesystem |
| GRES (`gres.conf`) | 8×H100 NVLink map | 1×GPU `/dev/nvidia0` `Cores=0-15` | Stock map is 8-GPU-only; slurmctld crashes on 16 CPUs |
| `node_local_image_disk` | 930 GiB IO_M3 | disabled | Enroot/Docker image disks are unused |
| Backups | auto | `force_disable` | Smaller surface for a short-lived lab |

## CPU nodeset budget

| Nodeset | Platform | Preset | Count | vCPU |
| --- | --- | --- | --- | --- |
| System | cpu-d3 | 8vcpu-32gb | 4 (fixed) | 32 |
| Login | cpu-d3 | 16vcpu-64gb | 1 | 16 |
| Controller | cpu-d3 | 4vcpu-16gb | 1 | 4 |
| **CPU total** | | | **6** | **52** |

GPU workers are additional: 2 × `1gpu-16vcpu-200gb` (2 H100s, 32 vCPU). They are not in the 52 vCPU table.

## Region

`gpu-h100-sxm` is documented for `eu-north1`. If the project is in another region, confirm GPU platform and preset before `terraform apply`.
