# Operators, ArgoCD, and the NCCL test

This environment reuses the solutions library and Nebius marketplace charts. It does not add a second Kubernetes training stack.

## What is reused

- **Cluster:** official [Soperator Terraform](https://github.com/nebius/nebius-solutions-library/tree/soperator-v4.1.8-1/soperator) in `terraform/infra` (MK8s and disks) and `terraform/platform` (Flux and Slurm)
- **GPU Operator:** same marketplace OCI chart as [Working with GPUs](https://docs.nebius.com/kubernetes/gpu/set-up), Helm in `terraform/platform` (`driver.enabled=false`). Network Operator is not installed (no InfiniBand).
- **NCCL job:** [Running NCCL tests with InfiniBand-connected GPUs](https://docs.nebius.com/kubernetes/gpu/nccl-test), ranks and resources set for **2×1 H100 and no InfiniBand**

The tutorial node group is `8gpu-128vcpu-1600gb` plus a GPU cluster (`fabric-3`). This lab cannot use that shape. The MPIJob still uses Nebius’s `nccl-tests` image and Kubeflow Training Operator.

Helm and Kubernetes providers use **`terraform/kubeconfig`** (written by the infra apply, gitignored). Kubeconfig is not stored in Vault.

## After infra apply

### Platform (Soperator, operators, ArgoCD)

```bash
./scripts/03-apply_platform.sh
```

Applies `terraform/platform` (Flux, Soperator/Slurm, GPU Operator with `driver.enabled=false`, Training Operator v1.9.3, ArgoCD) then `terraform/workloads` (`login.sh`, namespaces, ConfigMap).

```bash
export KUBECONFIG="$PWD/terraform/kubeconfig"
kubectl get pods -n flux-system
kubectl get slurmcluster -A
kubectl get pods -n nvidia-gpu-operator
kubectl get pods -n kubeflow
```

### NCCL test (requires free GPUs)

Soperator worker pods already consume both H100s.

```bash
./scripts/04-scale_slurm_gpu_workers.sh 0
cd terraform/workloads
source ../infra/.envrc && source ./envrc.example
terraform apply -var=enable_nccl_mpijob=true
kubectl -n nccl-test get pods -w
kubectl -n nccl-test logs -f job/nccl-test-nebius-launcher
# all_reduce_perf numbers. BusBW is Ethernet, not ~300 GB/s InfiniBand.
terraform apply -var=enable_nccl_mpijob=false   # or kubectl -n nccl-test delete mpijob nccl-test-nebius
./scripts/04-scale_slurm_gpu_workers.sh 2
```

Continue with `sbatch train.sbatch` after workers are restored.

## Why Soperator instead of k8s-training

[`k8s-training`](https://github.com/nebius/nebius-solutions-library/tree/main/k8s-training) is the GPU-Operator + Network-Operator + InfiniBand training cluster. This demo requires **Soperator**. Infra creates one MK8s cluster; platform installs Soperator, GPU Operator, and Training Operator on it.
