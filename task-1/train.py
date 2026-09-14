#!/usr/bin/env python3
"""LoRA SFT of Qwen2.5-7B-Instruct.

- Hugging Face `transformers` loads the base instruct model.
- Default data is `databricks/databricks-dolly-15k` (`train[:1500]`), cached in HF_HOME.
- Optional `TRAIN_DATA` JSONL with a `messages` column (Helios fallback).
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
    parser = argparse.ArgumentParser(description="LoRA SFT")
    parser.add_argument("--batch-size", type=int, default=int(os.environ.get("PER_DEVICE_BATCH", "4")))
    parser.add_argument(
        "--data",
        default=os.environ.get("TRAIN_DATA", ""),
        help="Optional local JSONL with a messages column. Empty = load --hf-dataset.",
    )
    parser.add_argument("--hf-dataset", default=os.environ.get("HF_DATASET", "databricks/databricks-dolly-15k"))
    parser.add_argument("--hf-split", default=os.environ.get("HF_SPLIT", "train[:1500]"))
    parser.add_argument("--epochs", type=float, default=float(os.environ.get("EPOCHS", "1")))
    parser.add_argument("--grad-accum", type=int, default=int(os.environ.get("GRAD_ACCUM", "4")))
    parser.add_argument("--lora-alpha", type=int, default=int(os.environ.get("LORA_ALPHA", "32")))
    parser.add_argument("--lora-r", type=int, default=int(os.environ.get("LORA_R", "16")))
    parser.add_argument("--lr", type=float, default=float(os.environ.get("LR", "2e-4")))
    parser.add_argument("--max-seq-len", type=int, default=int(os.environ.get("SEQ_LEN", "2048")))
    parser.add_argument("--model", default=os.environ.get("BASE_MODEL", "Qwen/Qwen2.5-7B-Instruct"))
    parser.add_argument("--output", default=os.environ.get("OUTPUT_DIR", "/mnt/data/nebius-demo/checkpoints/dolly-lora"))
    return parser.parse_args()


def dolly_to_messages(example: dict) -> dict:
    instruction = (example.get("instruction") or "").strip()
    context = (example.get("context") or "").strip()
    response = (example.get("response") or "").strip()
    user = f"{instruction}\n\n{context}" if context else instruction
    return {
        "messages": [
            {"role": "user", "content": user},
            {"role": "assistant", "content": response},
        ]
    }


def load_sft_dataset(args: argparse.Namespace):
    if args.data:
        print(f"dataset=json data_files={args.data}")
        return load_dataset("json", data_files=args.data, split="train")

    cache_dir = os.environ.get("HF_HOME")
    print(f"dataset={args.hf_dataset} split={args.hf_split} hf_home={cache_dir}")
    ds = load_dataset(args.hf_dataset, split=args.hf_split)
    if "messages" in ds.column_names:
        return ds
    return ds.map(dolly_to_messages, remove_columns=ds.column_names)


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

    dataset = load_sft_dataset(args)

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
        target_modules=["down_proj", "gate_proj", "k_proj", "o_proj", "q_proj", "up_proj", "v_proj"],
    )

    sft_args = SFTConfig(
        bf16=True,
        dataloader_num_workers=2,
        dataset_text_field="text",
        ddp_find_unused_parameters=False,
        gradient_accumulation_steps=args.grad_accum,
        gradient_checkpointing=True,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        learning_rate=args.lr,
        logging_steps=1,
        lr_scheduler_type="cosine",
        max_grad_norm=1.0,
        max_length=args.max_seq_len,
        num_train_epochs=args.epochs,
        output_dir=args.output,
        packing=True,
        per_device_train_batch_size=args.batch_size,
        report_to=[],
        save_strategy="epoch",
        warmup_ratio=0.03,
    )

    trainer = SFTTrainer(
        args=sft_args,
        model=model,
        peft_config=lora,
        processing_class=tokenizer,
        train_dataset=dataset,
    )

    trainer.train()

    if local_rank == 0:
        Path(args.output).mkdir(parents=True, exist_ok=True)
        trainer.save_model(args.output)
        tokenizer.save_pretrained(args.output)
        print(f"saved LoRA adapters to {args.output}")


if __name__ == "__main__":
    main()
