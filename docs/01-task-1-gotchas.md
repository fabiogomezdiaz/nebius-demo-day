# Task 1 gotchas

Things that bit this lab while putting Soperator `4.1.8` on **2×1×H100 Ethernet** (preset `1gpu-16vcpu-200gb`) and running two-node LoRA SFT. The stock recipe assumes **8×H100 + InfiniBand**.

Terraform overlay detail: [terraform-infiniband-changes.md](terraform-infiniband-changes.md). Runbook: [01-task-1-soperator-training.md](01-task-1-soperator-training.md).

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

**GRES** is Slurm’s **Generic RESource** map. `slurmctld` (the scheduler) does not discover GPUs the way Kubernetes does. It reads `gres.conf`: device file (`/dev/nvidia0`), GPU type, and which CPU IDs may use that GPU (`Cores=…`). Soperator writes that file from Terraform `worker_nodesets[].gres_config`. Kubernetes `nvidia.com/gpu` is a separate path.

Stock `gres_config_by_platform["gpu-h100-sxm"]` is the **8-GPU NVLink** map (`/dev/nvidia0`–`7`, `Cores=0-31` / `32-63`). These workers are 1 GPU / 16 CPUs (`S:C:T = 1:8:2`). `slurm.conf` already said `CPUs=16` and `Gres=gpu:...:1`. `gres.conf` did not.

There are two failure modes. Do not stop at the first.

### `Cores=0-31` — slurmctld CrashLoop

```text
fatal: Invalid GRES data for gpu, Cores=0-31 (only 16 CPUs are available)
```

`controller-0` CrashLoopBackOff. Workers stay `Init:3/4` pinging a DOWN controller.

### `Cores=0-15` — controller starts, GPU jobs never place

`gres.conf Cores=` is **logical cores on a complete socket**, not CPU thread IDs. `cpus - 1` = `15` is wrong on this SKU. `slurmctld` logs:

```text
error: _foreach_rebuild_topo: gres/gpu: invalid GRES core specification (0-15) on node worker-0
```

Then:

- `scontrol show node` still shows `Gres=gpu:nvidia_h100_80gb_hbm3:1`
- `CfgTRES=cpu=16,mem=176G,billing=16` with **no `gres/gpu`**
- Both workers `idle`, GPU jobs `PD (Resources)`
- CPU-only jobs (`srun` without GRES) run, but `nvidia-smi` in those jobs is `No devices were found`

**Fix** in `terraform/infra/04-outputs.tf`: when `gpus == 1`, emit one line, `/dev/nvidia0`, `Cores=0-7` (`boards × sockets_per_board × cores_per_socket - 1`). Apply **infra** then **platform**. After a good map, `Gres=` becomes `gpu:…:1(S:0)` (bound to socket 0).

`CfgTRES` may still omit `gres/gpu` in `scontrol show node`. That is accounting. Trust `Gres=…(S:0)` plus `cuda=True` in the training log.

### Live patch (do not wait for a 240-minute platform apply)

Flux HelmRelease `flux-system-soperator-fluxcd-nodesets` reconciles every **5 minutes** and will put `Cores=0-15` back if you only edit `gres.conf`. Patch all four, then bounce `slurmctld` (`Cores=` changes need a restart, not just `scontrol reconfigure`):

1. `NodeSet` `worker` `spec.nodeConfig.gresConfig`
2. HelmRelease `flux-system-soperator-fluxcd-nodesets` values
3. ConfigMap `soperator/soperator-slurm-configs` key `gres.conf`
4. ConfigMap `flux-system/terraform-fluxcd-values` (parent values)

Then `kubectl -n soperator delete pod controller-0` and wait Ready. A GPU job that was `PD` can start as soon as the controller is back.

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

## Hidden-partition checks steal GPUs and use a truncated user name

Soperator ActiveChecks (`cuda-samples`, `all-reduce-perf-nccl-*`, `gpu-fryer`, …) submit as Slurm user **`soperato`**, not `soperator`. `scancel -u soperator` fails with `Invalid user name`. Cancel by job id or `scancel -u soperato`.

Those jobs sit on partition **`hidden`**. They can leave `GresUsed` non-zero or keep a training job `PD (Resources)` / `Nodes required for job are DOWN, DRAINED or reserved for jobs in higher priority partitions`. Cancel them before a training run.

## Submitting the training job

Training is `sbatch` on the login node. Worker pods already bind `nvidia.com/gpu`; a Kubernetes GPU Deployment stays `Pending`.

What actually ran (job 66): two nodes, `--gpus-per-node=1`, `--ntasks-per-node=1`, `--cpus-per-task=1`, `--mem=80G`, then `bash train.sbatch` as `--wrap`. `#SBATCH` lines inside the wrapped script are **ignored**; flags must be on the `sbatch` command (or you must `sbatch train.sbatch` without `--wrap`).

| Flag / habit | What happens |
| --- | --- |
| No GRES (`sbatch` CPU-only, or `--gpus-per-node` ignored while `Cores=0-15`) | Job runs; `cuda=False`; `nvidia-smi`: no devices. Do not treat this as a successful train. |
| `--gres=gpu:1` on a **bare** `srun` outside an allocation | `Invalid generic resource (gres) specification` |
| `--exclusive --mem=0` | `ReqTRES` asks for all RAM (`mem=352G` on two nodes). Pending reason: nodes DOWN, DRAINED, or reserved for higher-priority partitions — even when `sinfo` shows idle. |
| `--gpus-per-node=1` with a valid `Cores=0-7` map | `TresPerNode=gres/gpu:1`. This is the Nebius-doc pattern that placed the job. |

Confirm before assuming the queue is the problem:

```bash
scontrol show node worker-0 | egrep 'Gres|CfgTRES|State|Reason'
scontrol show job <id> | egrep 'JobState|Reason|ReqTRES|TresPerNode|NodeList'
```

You want `Gres=gpu:…:1(S:0)` on the node and `TresPerNode=gres/gpu:1` on the job.

## NCCL must be forced onto Ethernet

This preset has no IB NIC. Without these, `torchrun` hangs at NCCL init:

```bash
export NCCL_IB_DISABLE=1
export NCCL_NET=Socket
export NCCL_SOCKET_IFNAME="${NCCL_SOCKET_IFNAME:-eth0}"
```

`hostname -I` on the worker can return **docker0** (`172.17.0.1`) first. Rendezvous then binds the wrong address and NCCL never forms (or both ranks come up as rank 0). `train.sbatch` takes the IPv4 address of `eth0` instead.

If it still hangs, run `ip -br addr` on a worker and set `NCCL_SOCKET_IFNAME` / rendezvous to that interface.

## Training files are not in Terraform

`train.py` / `train.sbatch` / the dataset get onto `/mnt/data` with `04-sync_workloads.sh`. SSH with `05-login.sh` (default key `~/.ssh/id_rsa`). Install Python into `/mnt/data` (or jail root), not node-local `/tmp`, or rank 1 will not see the env.

Success for this lab: `world_size=2`, `cuda=True`, `n_gpu=1` **per rank** (two nodes, one H100 each), adapters at `/mnt/data/nebius-demo/checkpoints/helios-lora`. `n_gpu=2` in one process would be wrong on this SKU.

## Topology labels persist after a platform wipe

Ethernet nodes do not get InfiniBand labels `topology.nebius.com/tier-0` / `tier-1`. Manual `unknown` labels on the GPU nodes **survived** platform wipe. If a second platform apply mis-schedules or topology plugins complain, check leftover node labels.

## VictoriaMetrics Pending is expected

**VictoriaMetrics** is a Prometheus-compatible time-series database. Soperator’s optional in-cluster metrics stack (the `victoria-metrics-k8s-stack` Helm chart) deploys a `vmsingle` pod to scrape Slurm and node metrics. Nebius **public o11y** is a different path: hosted telemetry that needs a `soperator-telemetry` IAM profile. This lab sets `public_o11y_enabled = false`, so we do not use either path for the demo.

The chart still schedules `vmsingle-metrics-victoria-metrics-k8s-stack` on the system nodes. Those four `8vcpu` nodes are already full (Flux, GPU Operator, kube-system). The pod stays **Pending**. Ignore it. Do not add system nodes just to schedule it.

## GPU Operator: drivers already on the node

MK8s uses the driverfull GPU image (`use_preinstalled_gpu_drivers = true`). Install GPU Operator from the marketplace with **`driver.enabled=false`**. Leaving the driver on dual-installs CUDA and the node never becomes Ready.

Do not also install the same chart from the Nebius console.

## Flux is not optional

Soperator installs the operator and `SlurmCluster` as Flux HelmReleases. Removing Flux breaks Slurm. It is not app GitOps.

## Helm `keep` means Terraform destroy is not enough

Flux HelmReleases use `helm.sh/resource-policy: keep`. `terraform destroy` in platform uninstalls the Helm release object and leaves namespaces, CRDs, and finalizers. Destroy **platform → infra** so wipe still has a cluster.

`06-destroy_platform.sh` runs `terraform/platform/scripts/platform_k8s_wipe.sh` after destroy. The wipe marker in `cleanup.tf` is created **first** so it is always in state even if Soperator apply hangs.

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
| GPU jobs `PD (Resources)` on idle nodes; `CfgTRES` has no `gres/gpu` | `gres.conf` `Cores=0-15` (thread IDs); need `Cores=0-7` |
| `03-apply_platform.sh` sits on `wait_for_soperator_activechecks_hr` | Overlay missing or `depends_on module.slurm` |
| `sinfo` empty / `srun` PD `(PartitionConfig)` | `slurmctld` never reloaded; REST missing |
| Nodes `IDLE+CLOUD+POWERED_DOWN` | Need POWER_UP (and maybe slurmd restart) |
| Nodes `idle*` / DOWN after drain | `scontrol update NodeName=… State=RESUME`; check slurmd |
| `soperator-rest-svc` / `no such host` | REST not deployed; reconfigure is manual |
| `scancel: Invalid user name: soperator` | Hidden checks run as `soperato` |
| `Nodes required for job are DOWN, DRAINED or reserved…` | Hidden jobs, `--exclusive --mem=0`, or GRES reset |
| Job runs but `cuda=False` / no NVIDIA devices | Allocation has no GRES; do not train |
| `Invalid generic resource (gres) specification` | `--gres` on a `srun` with no GPU allocation |
| Rendezvous `172.17.0.1` / both ranks are 0 | `hostname -I` picked docker0; use `eth0` |
| NCCL hang at init | IB not disabled or wrong `NCCL_SOCKET_IFNAME` |
| VictoriaMetrics Pending | Ignore |
| Topology labels after wipe | Leftover `topology.nebius.com/*` on GPU nodes |
| GPU Deployment Pending | Workers already hold the GPUs |
| Public o11y / missing telemetry profile | `public_o11y_enabled` still true |
| `yq: command not found` | Prereqs not installed |
| Jail change missing on a worker | Installed in `/tmp` instead of `/mnt/data` |
| Platform destroy leaves Flux/Soperator | Helm `keep`; run wipe after destroy |
| Live `Cores=0-7` reverts to `0-15` | Flux nodesets HelmRelease; patch values + NodeSet, or apply infra then platform |
