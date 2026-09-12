#!/usr/bin/env python3
"""Generate the Demo Day PowerPoint. Run: python3 presentation/generate_pptx.py"""

from __future__ import annotations

from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_AUTO_SHAPE_TYPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

NAVY = RGBColor(0x0B, 0x1F, 0x33)
TEAL = RGBColor(0x1F, 0x7A, 0x6B)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
INK = RGBColor(0x1A, 0x1A, 0x1A)
MUTED = RGBColor(0x4A, 0x55, 0x60)
LIGHT = RGBColor(0xF4, 0xF6, 0xF8)
CARD = RGBColor(0xE8, 0xEE, 0xF2)

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "Nebius-Demo-Day.pptx"


def set_run(run, text, size=18, bold=False, color=INK, font="Calibri"):
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    run.font.name = font


def add_bar(slide, prs):
    bar = slide.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.RECTANGLE, Inches(0), Inches(0), prs.slide_width, Inches(0.12)
    )
    bar.fill.solid()
    bar.fill.fore_color.rgb = TEAL
    bar.line.fill.background()


def add_footer(slide, prs, page, total):
    box = slide.shapes.add_textbox(Inches(0.5), Inches(7.05), Inches(11.5), Inches(0.3))
    tf = box.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    run = p.add_run()
    set_run(run, f"Nebius Demo Day  ·  Soperator on 2×H100  ·  {page}/{total}", size=11, color=MUTED)


def blank(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = WHITE
    add_bar(slide, prs)
    return slide


def title_block(slide, title, subtitle=None):
    box = slide.shapes.add_textbox(Inches(0.55), Inches(0.28), Inches(12), Inches(0.9))
    tf = box.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    run = p.add_run()
    set_run(run, title, size=28, bold=True, color=NAVY)
    if subtitle:
        p2 = tf.add_paragraph()
        run2 = p2.add_run()
        set_run(run2, subtitle, size=14, color=MUTED)


def bullets(slide, items, top=1.35, left=0.6, width=12.2, height=5.4, size=18):
    box = slide.shapes.add_textbox(Inches(left), Inches(top), Inches(width), Inches(height))
    tf = box.text_frame
    tf.word_wrap = True
    tf.clear()
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.level = 0
        p.space_after = Pt(10)
        run = p.add_run()
        set_run(run, item, size=size, color=INK)


def card(slide, left, top, width, height, heading, body_lines):
    shape = slide.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
        Inches(left),
        Inches(top),
        Inches(width),
        Inches(height),
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = LIGHT
    shape.line.fill.background()
    tf = shape.text_frame
    tf.word_wrap = True
    tf.clear()
    p = tf.paragraphs[0]
    run = p.add_run()
    set_run(run, heading, size=16, bold=True, color=TEAL)
    for line in body_lines:
        p2 = tf.add_paragraph()
        p2.space_before = Pt(6)
        run2 = p2.add_run()
        set_run(run2, line, size=13, color=INK)


def build() -> None:
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    total = 10

    # 1 title
    s = blank(prs)
    band = s.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.RECTANGLE, Inches(0), Inches(0), Inches(0.28), prs.slide_height
    )
    band.fill.solid()
    band.fill.fore_color.rgb = NAVY
    band.line.fill.background()
    box = s.shapes.add_textbox(Inches(0.9), Inches(2.1), Inches(11.5), Inches(3))
    tf = box.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    run = p.add_run()
    set_run(run, "Nebius Demo Day", size=40, bold=True, color=NAVY)
    p2 = tf.add_paragraph()
    r2 = p2.add_run()
    set_run(r2, "Soperator on 2×H100 without InfiniBand", size=22, color=TEAL)
    p3 = tf.add_paragraph()
    p3.space_before = Pt(16)
    r3 = p3.add_run()
    set_run(r3, "Distributed LoRA fine-tune on Soperator — 2×H100 over Ethernet", size=16, color=MUTED)
    p4 = tf.add_paragraph()
    p4.space_before = Pt(28)
    r4 = p4.add_run()
    set_run(r4, "Recipe soperator-v4.1.8-1  ·  Qwen2.5-7B-Instruct + LoRA", size=14, color=INK)
    add_footer(s, prs, 1, total)

    # 2 agenda
    s = blank(prs)
    title_block(s, "Demo objectives")
    card(s, 0.5, 1.4, 12.3, 2.4, "Task 1 — cluster and training", [
        "Deploy Soperator from the pinned tag, not main.",
        "Run distributed LoRA fine-tuning on two Ethernet H100s.",
        "Overlay Terraform so 1×H100 nodes work without InfiniBand.",
    ])
    card(s, 0.5, 4.05, 12.3, 2.5, "Hard limits", [
        "2×H100 total, 1 GPU per node. Single MK8s cluster.",
        "1gpu-16vcpu-200gb cannot join a GPU cluster / IB fabric.",
        "CPU nodesets: 6 nodes / 52 vCPU. public_o11y_enabled = false. One jail filesystem, not shared with another jail.",
        "Retain the environment for the duration of the demo.",
    ])
    add_footer(s, prs, 2, total)

    # 3 translator slide
    s = blank(prs)
    title_block(s, "GPU Operator and Soperator")
    bullets(s, [
        "GPU Operator makes nvidia.com/gpu real on Kubernetes. Soperator makes Slurm real on Kubernetes.",
        "One MK8s cluster. Jobs are submitted with sbatch on the login node, not as GPU Deployments.",
        "The jail is a shared root filesystem. Python is installed once; both H100 workers see the same env and /mnt/data.",
        "Fine-tune = continue training a pretrained model on domain examples. LoRA = train small adapters, not all 7B weights.",
        "Distributed = two processes (one GPU each) averaging gradients. NCCL does that; here it must use Ethernet, not IB.",
    ], size=17)
    add_footer(s, prs, 3, total)

    # 4 architecture
    s = blank(prs)
    title_block(s, "Architecture — one cluster, two Ethernet H100s")
    card(s, 0.5, 1.35, 4.0, 5.1, "CPU nodesets (52 vCPU)", [
        "System  4 × 8 vCPU",
        "Login  1 × 16 vCPU",
        "Controller  1 × 4 vCPU",
        "",
        "No NFS node. No slurmdbd.",
        "Login is the SSH front door.",
        "Controller is the Slurm brain.",
    ])
    card(s, 4.7, 1.35, 4.0, 5.1, "GPU workers", [
        "2 × gpu-h100-sxm",
        "Preset 1gpu-16vcpu-200gb",
        "gpu_cluster = null",
        "",
        "No IB NIC, no GPU cluster object.",
        "NCCL over TCP (eth0).",
        "Training uses both cards.",
    ])
    card(s, 8.9, 1.35, 3.9, 5.1, "Storage", [
        "New jail filesystem (256 GiB).",
        "Data submount /mnt/data (512 GiB).",
        "Models, dataset, adapters, logs.",
        "",
        "Do not reuse another jail FS.",
        "Drivers from Nebius GPU image.",
        "Network Operator skipped.",
    ])
    add_footer(s, prs, 4, total)

    # 5 terraform
    s = blank(prs)
    title_block(s, "The InfiniBand Terraform change")
    bullets(s, [
        "Stock example: gpu_cluster = { infiniband_fabric = \"\" }  — validation fails (id or fabric required).",
        "Stock example: 8gpu-128vcpu-1600gb  — that preset is IB-capable; ours is not.",
        "Fix: preset = 1gpu-16vcpu-200gb and gpu_cluster = null.",
        "That leaves local.gpu_clusters_v2 empty, so Terraform does not create nebius_compute_v1_gpu_cluster.",
        "MK8s node group template.gpu_cluster stays unset. use_preinstalled_gpu_drivers = true skips Network Operator.",
        "Also required: GRES overlay (stock 8-GPU map crashes slurmctld on 16 CPUs), public_o11y_enabled = false, active_checks_scope = \"essential\", shm 64 GiB not 1024 GiB.",
        "Pinned tag soperator-v4.1.8-1 / operator 4.1.8. production = false for the sandbox.",
    ], size=16)
    add_footer(s, prs, 5, total)

    # 6 task 1
    s = blank(prs)
    title_block(s, "Task 1 — distributed LoRA fine-tune")
    bullets(s, [
        "Model: Qwen2.5-7B-Instruct. Method: LoRA SFT (rank 16) with Hugging Face TRL.",
        "Dataset: 40 made-up Helios Robotics FAQ pairs. Base model cannot know Mira Chen or HX-441.",
        "Launch: sbatch train.sbatch → srun torchrun --nnodes 2 --nproc_per_node 1.",
        "NCCL_IB_DISABLE=1, NCCL_NET=Socket, NCCL_SOCKET_IFNAME=eth0.",
        "Checkpoint: /mnt/data/nebius-demo/checkpoints/helios-lora (adapters only).",
        "Why 7B not 1.5B: large enough to load the H100s; small enough to finish in the lab.",
        "Pass signal: squeue on 2 nodes, world_size=2 in the log, adapters on disk, both GPUs busy.",
    ], size=16)
    add_footer(s, prs, 6, total)

    # 7 demo flow
    s = blank(prs)
    title_block(s, "Live demo flow")
    bullets(s, [
        "Constraints + gpu_cluster sentinel in tfvars.",
        "kubectl get nodes and sinfo. Two GPU workers.",
        "Training log (world_size=2) and LoRA checkpoint.",
        "GPU dashboard screenshot from the training run.",
        "Leave the cluster up. Do not terraform destroy.",
    ], size=17)
    add_footer(s, prs, 7, total)

    # 10 design decisions
    s = blank(prs)
    title_block(s, "Design decisions to defend")
    bullets(s, [
        "Slurm jobs instead of k8s Deployments — GPUs are already in the Soperator worker pods.",
        "LoRA instead of full SFT — faster, smaller artifact, still a real fine-tune.",
        "Synthetic FAQ instead of Alpaca — the quality delta is visible in a 30-second curl.",
        "GRES overlay — stock gres.conf is 8×H100 (Cores=0-31). This preset is 1 GPU / 8 cores; slurmctld CrashLoops without /dev/nvidia0 Cores=0-7.",
        "essential active checks — IB NCCL health checks cannot pass on this preset.",
        "New jail + /mnt/data — a jail filesystem must not be shared across two clusters.",
        "If we had 8×H100 + IB: restore infiniband_fabric, 8gpu preset, drop NCCL_IB_DISABLE, nproc_per_node=8.",
    ], size=16)
    add_footer(s, prs, 8, total)

    # 11 troubleshoot
    s = blank(prs)
    title_block(s, "Likely failures")
    bullets(s, [
        "controller-0 CrashLoop — stock GRES Cores=0-31 on a 16-CPU node. Overlay 04-outputs.tf then re-apply platform.",
        "Validation error on gpu_cluster — empty infiniband_fabric is still set.",
        "Node group API error — fabric/id still set on a 1-GPU preset.",
        "yq: command not found — install yq on the machine running Terraform.",
        "Public o11y / missing telemetry profile — public_o11y_enabled still true.",
        "NCCL hang at init — IB not disabled or wrong NCCL_SOCKET_IFNAME (run ip -br addr).",
        "OOM — lower PER_DEVICE_BATCH; 7B LoRA on 80 GB should otherwise be comfortable.",
    ], size=16)
    add_footer(s, prs, 9, total)

    # 12 close
    s = blank(prs)
    title_block(s, "Ask / next")
    bullets(s, [
        "Sandbox console + Slack invites, if they are not in yet.",
        "Confirm region has gpu-h100-sxm (docs: eu-north1).",
        "SSH public key path in terraform.tfvars, then bootstrap + apply.",
        "Task 1 is the pass: two-node LoRA SFT on Soperator.",
        "Repo: docs, Terraform overlay, workloads, and this deck.",
    ], size=18)
    add_footer(s, prs, 10, total)

    prs.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    build()
