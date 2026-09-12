# Demo Day assignment (source brief)

Copied from the Demo Day email for reference. Progress against it: [00-status.md](00-status.md).

## Tasks

Run a distributed training/fine-tuning job utilizing our Soperator solution. Choose the **latest version tag**, not `main` — [nebius/nebius-solutions-library](https://github.com/nebius/nebius-solutions-library) `soperator`.

Run **inference** on the same Kubernetes cluster, serving the trained model.

Run the **original (untrained)** model, and **compare** the results of both models.

Utilize **more than 80% of the GPUs** (Nebius console includes monitoring dashboards).

## Capacity limits

- Training and inference GPU limit = **2×H100** (**1×H100 per node**).
- **Single MK8s cluster** at a time.
- The **single-H100 GPU node preset does not support InfiniBand**, so the standard Soperator Terraform recipe (which assumes an InfiniBand fabric / GPU Cluster artifact) will not work as-is. Manipulate the Soperator Terraform solution to make it work with a **single-GPU node and without InfiniBand**.

## Timelines

- Assignment period: **1 week** from receiving the email.
- To submit: reply on the email thread, elaborate on what succeeded and what challenged you, and **attach the Terraform code** used for the deployment.
- **Do not destroy** the lab environment. Keep it for the demo day meeting.
- Decommission the cluster **after** the demo day interview.

## Guidelines

- Avoid using the same shared filesystem for **2 different jails**.
- Open issue in the Terraform recipe: in `.tfvars`, set `public_o11y_enabled = false`.
- Install `yq` on the shell that runs `terraform apply`.
- Dataset and model of choice can be anything.
- Completing **task 1** is a pass and makes you eligible for the demo day interview. Completing **tasks 2–4** is extra mile / bonus.
- Follow the vCPU guidelines below for the Soperator cluster.

## CPU nodeset guidelines

| Nodeset | Platform | Preset | vCPU/node | Node count | Total vCPU (max) |
| --- | --- | --- | --- | --- | --- |
| System | cpu-d3 | 8vcpu-32gb | 8 | 4–24 (autoscaled) | 32 |
| Login | cpu-d3 | 16vcpu-64gb | 16 | 1 | 16 |
| Accounting | cpu-d3 | 8vcpu-32gb | 8 | 1 | 8 |
| Controller | cpu-d3 | 4vcpu-16gb | 4 | 1 | 4 |
| NFS | cpu-d3 | 4vcpu-16gb | 4 | 1 | 4 |
| **Total** | | | | **8 nodes** | **64** |

GPU workers are **in addition** to this table (2 × `1gpu-16vcpu-200gb`).

## Notes from the email

- If Slack / sandbox invitations have not arrived, reply on the email.
- Keep communications in Slack.
