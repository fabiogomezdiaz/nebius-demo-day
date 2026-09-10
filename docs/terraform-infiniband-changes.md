# Terraform changes vs the stock Soperator recipe

Pinned release: **`soperator-v4.1.8-1`** (Soperator operator version `4.1.8`). Do not use `main`.

The stock recipe lives in [nebius/nebius-solutions-library](https://github.com/nebius/nebius-solutions-library/tree/soperator-v4.1.8-1/soperator). We do not fork the modules. `scripts/bootstrap_soperator.sh` clones that tag and overlays `terraform/installations/demo-day/terraform.tfvars`.

## The InfiniBand trap

`1gpu-16vcpu-200gb` on `gpu-h100-sxm` is **not** in Nebius's GPU-cluster-compatible preset list. Only `8gpu-128vcpu-1600gb` can join an InfiniBand GPU cluster.

Three ways people break this:

1. Leave the example `gpu_cluster = { infiniband_fabric = "" }`. Variable validation requires a non-empty `id` or `infiniband_fabric` whenever the object is set.
2. Put a real fabric name in. Terraform then creates `nebius_compute_v1_gpu_cluster` and attaches it to the node group. The API rejects `1gpu-16vcpu-200gb`.
3. Install NVIDIA Network Operator / run NCCL IB health checks. Those assume an IB NIC that this preset does not expose.

## The required manipulation

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
gpu_cluster = null
```

What that does in the recipe (`soperator/modules/k8s/k8s_ng_workers_v2.tf`):

- `local.gpu_clusters_v2` is empty → no `nebius_compute_v1_gpu_cluster`.
- `template.gpu_cluster` on the MK8s node group is `null`.
- `use_preinstalled_gpu_drivers = true` skips Network Operator and GPU Operator (drivers come from the Nebius GPU image).

## Other assignment-required knobs

| Knob | Stock example | This lab | Why |
| --- | --- | --- | --- |
| `production` | `true` | `false` | Sandbox is not Soperator Pro; avoids IAM merge-request validation |
| `public_o11y_enabled` | `true` | `false` | Open issue in the recipe; assignment says turn it off |
| `active_checks_scope` | empty / prod | `"essential"` | Skip long NCCL-over-IB health checks that cannot pass |
| `slurm_shared_memory_size_gibibytes` | `1024` | `64` | Worker RAM is 200 GiB, not 1600 GiB |
| System nodeset | min 3 / max 9 | min 4 / max 4 | Cap at 32 vCPU |
| Login | 32vcpu-128gb × 2 | 16vcpu-64gb × 1 | Assignment table |
| Controller | 16vcpu-64gb | 4vcpu-16gb | Assignment table |
| Accounting | 8vcpu-32gb | 8vcpu-32gb × 1 | Assignment table |
| NFS | 32vcpu-128gb | 4vcpu-16gb | Assignment table |
| Jail | existing ID | new `spec` | Do not reuse another jail's filesystem |
| `node_local_image_disk` | 930 GiB IO_M3 | disabled | Not using Enroot/Docker images |
| Backups | auto | `force_disable` | Fewer moving parts in a 1-week lab |

## CPU nodeset budget (from the invitation)

| Nodeset | Platform | Preset | Count | vCPU |
| --- | --- | --- | --- | --- |
| System | cpu-d3 | 8vcpu-32gb | 4 (fixed) | 32 |
| Login | cpu-d3 | 16vcpu-64gb | 1 | 16 |
| Accounting | cpu-d3 | 8vcpu-32gb | 1 | 8 |
| Controller | cpu-d3 | 4vcpu-16gb | 1 | 4 |
| NFS | cpu-d3 | 4vcpu-16gb | 1 | 4 |
| **CPU total** | | | **8** | **64** |

GPU workers are extra: 2 × `1gpu-16vcpu-200gb` (2 H100s, 32 vCPU). They are not in that 64 vCPU table.

## Region

`gpu-h100-sxm` is documented for `eu-north1`. If the sandbox is in another region, stop and confirm GPU platform/preset with the Solutions Architects in Slack before `apply`.
