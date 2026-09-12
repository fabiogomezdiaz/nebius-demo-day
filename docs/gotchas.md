# Gotchas

Things that bit this lab while putting Soperator `4.1.8` on **2×1×H100 Ethernet** (preset `1gpu-16vcpu-200gb`). The stock recipe assumes **8×H100 + InfiniBand**. Deep dive on the InfiniBand skip and GRES (how Slurm is told which GPUs exist): [terraform-infiniband-changes.md](terraform-infiniband-changes.md).

## Pin the recipe

Use tag **`soperator-v4.1.8-1`**, not `main`. Module APIs and Helm values move. `terraform init` fetches `git::` at that tag; this repo does not vendor the modules.

## `gpu_cluster` cannot be empty, null, or a real fabric

`1gpu-16vcpu-200gb` is **not** GPU-cluster compatible. Only `8gpu-128vcpu-1600gb` can join InfiniBand.

| What you try | What happens |
| --- | --- |
| `gpu_cluster = { infiniband_fabric = "" }` | Validation: must set `id` or `infiniband_fabric` |
| A real fabric name | Terraform creates `nebius_compute_v1_gpu_cluster`; the API rejects this preset |
| `gpu_cluster = null` | Semantically right, but stock `gpu_fabric_validation.tf` still requires `id` or fabric on **every** GPU preset |

**Fix:** `gpu_cluster = { id = "ethernet-not-attached" }`. Validation passes, `local.gpu_clusters_v2` stays empty, and `template.gpu_cluster` on the MK8s node group stays `null` because the preset is not compatible. The sentinel is never attached to a real GPU cluster.

Do not install Network Operator. There is no InfiniBand HCA.

## GRES is keyed by platform, not preset

**GRES** is Slurm’s **Generic RESource** map. `slurmctld` (the scheduler) does not discover GPUs the way Kubernetes does. It reads `gres.conf`: device file (`/dev/nvidia0`), GPU type, and which CPU IDs may use that GPU (`Cores=…`). Soperator writes that file from Terraform `worker_nodesets[].gres_config`. If the map claims more CPUs or devices than the node has, `slurmctld` exits and the controller pod CrashLoops.

Stock `gres_config_by_platform["gpu-h100-sxm"]` is the **8-GPU NVLink** map (`/dev/nvidia0`–`7`, `Cores=0-31` / `32-63`). These workers are 1 GPU / 16 CPUs. `slurm.conf` already said `CPUs=16` and `Gres=gpu:...:1`. `gres.conf` did not.

```text
fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)
```

`controller-0` CrashLoopBackOff. Workers stay `Init:3/4` pinging a DOWN controller.

**Fix** in `terraform/infra/04-outputs.tf`: when `gpus == 1`, emit one line, `/dev/nvidia0`, `Cores=0-15`. Apply **infra** (updates the remote-state `soperator` object) then **platform** (Flux rewrites `gres.conf`). Kubernetes `nvidia.com/gpu` is a separate path; this crash is only Slurm.

**Follow-on:** `slurmctld` later logged `invalid GRES core specification (0-15)`. These nodes are 8 physical cores × 2 threads; `Cores=0-7` may be more correct for GPU binding. Training still ran with `0-15`. If GPU jobs start failing on core maps, try `0-7`.

## Activechecks hang the platform apply for 240 minutes

The slurm module **always** waits on HelmRelease `flux-system-soperator-fluxcd-soperator-activechecks`. That wait is not a tfvar.

`active_checks_scope = "essential"` skips the long NCCL-over-IB checks, but **still** leaves `ensure-healthy-nodes` and `wait-for-soperatorchecks-srun-ready` as `runAfterCreation=true`. The chart install hook loops until those ActiveChecks get a status write.

On this lab that write never arrives during bootstrap:

1. `soperator-rest-svc` was never created. `sconfigcontroller` cannot reconfigure (`lookup soperator-rest-svc.soperator.svc ... no such host`).
2. `slurm.conf` on disk had `NodeName=worker-[0-1] State=CLOUD`, but `slurmctld` never reloaded. `scontrol show nodes` was empty. `srun --partition=hidden` sat PD `(PartitionConfig)`.
3. After a manual `scontrol reconfigure`, nodes were `IDLE+CLOUD+POWERED_DOWN` with `SuspendExcNodes=worker-[0-1]`.
4. After `POWER_UP` + slurmd restart, nodes went idle. Health jobs `test-controller-is-ready` and `ensure-healthy-nodes` **COMPLETED** (hostname / JSON check — not training).
5. The Helm hook still waited: `ensure-healthy-nodes.status.slurmJobsStatus.lastRunStatus` stayed null because `soperator-checks` was error-looping on CronJob creates.

**Fix:** `terraform/platform/04-soperator-flux-overlay.tf` patches Flux ConfigMap `soperator-fluxcd-values` (the module creates it **empty** and `ignore_changes` it) to set those two checks `runAfterCreation: false`. CronJobs remain for later manual runs.

**Do not** `depends_on = [module.slurm]`. The 240m wait is *inside* the module. The overlay must run in parallel, depending only on Flux + the wipe marker.

`soperator-rest-svc` can still be missing after apply. Soperator will not auto-reconfigure. If `sinfo` shows no nodes, `scontrol reconfigure` (and POWER_UP if they stay `POWERED_DOWN`).

## Topology labels persist after a platform wipe

Ethernet nodes do not get InfiniBand labels `topology.nebius.com/tier-0` / `tier-1`. Manual `unknown` labels on the GPU nodes **survived** platform wipe. Workers we used: `computeinstance-e00zp4hb84yztx7dmp`, `computeinstance-e00n34shytzph1hj79`. If a second platform apply mis-schedules or topology plugins complain, check leftover node labels.

## VictoriaMetrics Pending is expected

**VictoriaMetrics** is a Prometheus-compatible time-series database. Soperator’s optional in-cluster metrics stack (the `victoria-metrics-k8s-stack` Helm chart) deploys a `vmsingle` pod to scrape Slurm and node metrics. Nebius **public o11y** is a different path: hosted telemetry that needs a `soperator-telemetry` IAM profile. This lab sets `public_o11y_enabled = false`, so we do not use either path for the demo.

The chart still schedules `vmsingle-metrics-victoria-metrics-k8s-stack` on the system nodes. Those four `8vcpu` nodes are already full (Flux, GPU Operator, kube-system). The pod stays **Pending**. Ignore it. Do not add system nodes just to schedule it.

## GPU Operator: drivers already on the node

MK8s uses the driverfull GPU image (`use_preinstalled_gpu_drivers = true`). Install GPU Operator from the marketplace with **`driver.enabled=false`**. Leaving the driver on dual-installs CUDA and the node never becomes Ready.

Do not also install the same chart from the Nebius console.

## Flux is not optional

Soperator installs the operator and `SlurmCluster` as Flux HelmReleases. Removing Flux breaks Slurm. It is not app GitOps.

## Helm `keep` means Terraform destroy is not enough

Flux HelmReleases use `helm.sh/resource-policy: keep`. `terraform destroy` in platform uninstalls the Helm release object and leaves namespaces, CRDs, and finalizers. Destroy **workloads → platform → infra** so wipe still has a cluster.

`06-destroy_platform.sh` runs `terraform/platform/scripts/platform_k8s_wipe.sh` after destroy. The wipe marker in `cleanup.tf` is created **first** so it is always in state even if Soperator apply hangs.

## Soperator workers own both GPUs

Worker pods bind `nvidia.com/gpu`. A Kubernetes GPU Deployment (or an MPIJob) stays `Pending`. Training is `sbatch` on the login node.

Do not scale workers to 0 unless you are deliberately giving the GPUs to something else. Task 1 does not.

## Training files are not in Terraform

`03-apply_platform.sh` only writes `login.sh`. `train.py` / `train.sbatch` / the dataset get onto `/mnt/data` with `04-sync_workloads.sh`. Install Python into `/mnt/data` (or jail root), not node-local `/tmp`, or rank 1 will not see the env.

## NCCL must be forced onto Ethernet

This preset has no IB NIC. Without these, `torchrun` hangs at NCCL init:

```bash
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_SOCKET_IFNAME="${NCCL_SOCKET_IFNAME:-eth0}"
```

If it still hangs, run `ip -br addr` on a worker and set the interface explicitly. `NCCL_SOCKET_IFNAME` wrong → both ranks can come up as rank 0 if rendezvous also mismatches (`--nnodes` / `--rdzv_endpoint`).

## Do not reuse another cluster’s jail

A filestore that is already a jail for another Slurm cluster must not be attached here. Create new jail + `/mnt/data` specs.

## Smaller knobs that also fail if left at stock

| Setting | Stock | This lab | Why |
| --- | --- | --- | --- |
| `production` | `true` | `false` | Sandbox is not Soperator Pro; avoids IAM merge-request validation |
| `public_o11y_enabled` | `true` | `false` | Recipe expects a `soperator-telemetry` profile this project does not have |
| `slurm_shared_memory_size_gibibytes` | `1024` | `64` | Worker RAM is 200 GiB, not 1600 GiB |
| Accounting / NFS / backups | on | off (accounting hardcoded) | Not needed; demo I/O is jail + `/mnt/data` |
| `node_local_image_disk` | 930 GiB | disabled | Enroot/Docker image disks unused |
| System / login / controller size | large | 4+1+1 = 52 vCPU | Capacity table |

`yq` must be on `PATH` during apply (`00-install_prereqs.sh`). Region for `gpu-h100-sxm` is documented as `eu-north1`.

## Symptom → cause

| Symptom | Cause |
| --- | --- |
| `gpu_cluster must set either id or infiniband_fabric` | Empty fabric object still set |
| Node group API error on GPU cluster | Real fabric/id attached to a 1-GPU preset |
| `controller-0` CrashLoop, `Cores=0-31` | Stock 8-GPU `gres.conf` |
| `03-apply_platform.sh` sits on `wait_for_soperator_activechecks_hr` | Overlay missing or `depends_on module.slurm` |
| `sinfo` empty / `srun` PD `(PartitionConfig)` | `slurmctld` never reloaded; REST missing |
| Nodes `IDLE+CLOUD+POWERED_DOWN` | Need POWER_UP (and maybe slurmd restart) |
| `soperator-rest-svc` / `no such host` | REST not deployed; reconfigure is manual |
| VictoriaMetrics Pending | Ignore |
| Topology labels after wipe | Leftover `topology.nebius.com/*` on GPU nodes |
| GPU Deployment Pending | Workers already hold the GPUs |
| NCCL hang at init | IB not disabled or wrong `NCCL_SOCKET_IFNAME` |
| Public o11y / missing telemetry profile | `public_o11y_enabled` still true |
| `yq: command not found` | Prereqs not installed |
| Jail change missing on a worker | Installed in `/tmp` instead of `/mnt/data` |
| Platform destroy leaves Flux/Soperator | Helm `keep`; run wipe after destroy |
