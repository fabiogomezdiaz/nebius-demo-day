#!/usr/bin/env python3
"""LoRA SFT of Qwen2.5-7B-Instruct.

- Hugging Face `transformers` loads the base instruct model.
- `peft.LoraConfig` freezes those weights and trains small adapter matrices.
- `trl.SFTTrainer` runs supervised fine-tuning on chat `messages`.
- `torchrun` (started from train.sbatch) runs DDP across 2 nodes × 1 GPU.
- Checkpoints are the LoRA adapters only, not a full copy of Qwen.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import torch
from datasets import load_dataset
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
from trl import SFTConfig, SFTTrainer


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Helios LoRA SFT")
    parser.add_argument("--model", default=os.environ.get("BASE_MODEL", "Qwen/Qwen2.5-7B-Instruct"))
    parser.add_argument("--data", default=os.environ.get("TRAIN_DATA", "/mnt/data/nebius-demo/workloads/data/helios_faq.jsonl"))
    parser.add_argument("--output", default=os.environ.get("OUTPUT_DIR", "/mnt/data/nebius-demo/checkpoints/helios-lora"))
    parser.add_argument("--max-seq-len", type=int, default=int(os.environ.get("SEQ_LEN", "2048")))
    parser.add_argument("--batch-size", type=int, default=int(os.environ.get("PER_DEVICE_BATCH", "4")))
    parser.add_argument("--grad-accum", type=int, default=int(os.environ.get("GRAD_ACCUM", "4")))
    parser.add_argument("--epochs", type=float, default=float(os.environ.get("EPOCHS", "8")))
    parser.add_argument("--lr", type=float, default=float(os.environ.get("LR", "2e-4")))
    parser.add_argument("--lora-r", type=int, default=int(os.environ.get("LORA_R", "16")))
    parser.add_argument("--lora-alpha", type=int, default=int(os.environ.get("LORA_ALPHA", "32")))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    local_rank = int(os.environ.get("LOCAL_RANK", "0"))
    world_size = int(os.environ.get("WORLD_SIZE", "1"))

    print(f"local_rank={local_rank} world_size={world_size} cuda={torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"gpu={torch.cuda.get_device_name(0)} n_gpu={torch.cuda.device_count()}")

    tokenizer = AutoTokenizer.from_pretrained(args.model, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        args.model,
        torch_dtype=torch.bfloat16,
        attn_implementation="sdpa",
        trust_remote_code=True,
    )
    model.config.use_cache = False

    dataset = load_dataset("json", data_files=args.data, split="train")

    def to_text(example: dict) -> dict:
        # Chat template turns role/content messages into the Qwen instruct string.
        text = tokenizer.apply_chat_template(
            example["messages"],
            tokenize=False,
            add_generation_prompt=False,
        )
        return {"text": text}

    dataset = dataset.map(to_text, remove_columns=dataset.column_names)

    lora = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    )

    sft_args = SFTConfig(
        output_dir=args.output,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        logging_steps=1,
        save_strategy="epoch",
        bf16=True,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        max_length=args.max_seq_len,
        packing=True,
        dataset_text_field="text",
        report_to=[],
        ddp_find_unused_parameters=False,
        dataloader_num_workers=2,
        max_grad_norm=1.0,
    )

    trainer = SFTTrainer(
        model=model,
        args=sft_args,
        train_dataset=dataset,
        processing_class=tokenizer,
        peft_config=lora,
    )

    trainer.train()

    if local_rank == 0:
        Path(args.output).mkdir(parents=True, exist_ok=True)
        trainer.save_model(args.output)
        tokenizer.save_pretrained(args.output)
        print(f"saved LoRA adapters to {args.output}")


if __name__ == "__main__":
    main()
