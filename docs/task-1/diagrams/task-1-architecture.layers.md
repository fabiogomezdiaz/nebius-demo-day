# Task 1 architecture — compact MK8s columns

System nodes are one column. Platform pods on that column are stacked. `kube-system` is omitted (MK8s control plane).

IDs: [`eraser-ids.json`](eraser-ids.json). PNG: [`../static/task-1-architecture.png`](../static/task-1-architecture.png).

```
Infra (cloud)
├── Storage
│   ├── jail                 → CSI → slurmctld, sshd, slurmd+GPU (both workers)
│   ├── /mnt/data            → CSI → setup_env, torchrun, torchrun
│   └── controller spool     → CSI → slurmctld
└── MK8s
    COLUMNS:
      system 0-3          controller-0   login-0            worker-0         worker-1
      Flux                slurmctld      sshd               slurmd + GPU     slurmd + GPU
      Soperator operator
      GPU Operator
                                         05-login / sbatch  torchrun LoRA    torchrun LoRA
    PLATFORM overlay: system 0-3 stacked pods; plus controller-0 … worker-1
    WORKLOADS overlay: login-0 + worker-0 + worker-1
```
