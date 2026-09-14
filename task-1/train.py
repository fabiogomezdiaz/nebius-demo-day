#!/usr/bin/env python3
"""LoRA (Low-Rank Adaptation) SFT of Qwen2.5-7B-Instruct.

Quick summary:
- Uses huggingface transformers to load the model and tokenizer.
- Loads Dolly-15k from Hugging Face (`train[:1500]` by default).
- Creates a LoRA (Low-Rank Adaptation) adapter, which is a small set of weights in the model that can be changed during training (trainable weights).
- Fine-tunes only these LoRA (Low-Rank Adaptation) adapter weights, not the big base model.
- Only those LoRA (Low-Rank Adaptation) adapters are saved as checkpoints (not the whole model).
- Can be run distributed (multi-GPU/machines).

"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import torch                                                 # PyTorch: tensor operations and GPU access
from datasets import load_dataset                            # Hugging Face Datasets: loading and working with public or local datasets
from peft import LoraConfig                                  # PEFT (Parameter-Efficient Fine-Tuning): config object for LoRA (Low-Rank Adaptation) adapter parameters
from transformers import AutoModelForCausalLM, AutoTokenizer # Hugging Face Transformers: pre-trained model and tokenizer
from trl import SFTConfig, SFTTrainer                        # TRL (Transformer Reinforcement Learning Library): provides utilities for finetuning LLMs, including SFT (Supervised Fine-Tuning) config and trainer

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="LoRA (Low-Rank Adaptation) SFT")
    parser.add_argument("--batch-size", type=int, default=int(os.environ.get("PER_DEVICE_BATCH", "4")))
    parser.add_argument("--hf-dataset", default=os.environ.get("HF_DATASET", "databricks/databricks-dolly-15k"))
    parser.add_argument("--hf-split", default=os.environ.get("HF_SPLIT", "train[:1500]"))
    parser.add_argument("--epochs", type=float, default=float(os.environ.get("EPOCHS", "1")))
    parser.add_argument("--grad-accum", type=int, default=int(os.environ.get("GRAD_ACCUM", "4")))
    parser.add_argument("--lora-alpha", type=int, default=int(os.environ.get("LORA_ALPHA", "32"))) # LoRA (Low-Rank Adaptation) scaling factor
    parser.add_argument("--lora-r", type=int, default=int(os.environ.get("LORA_R", "16")))         # LoRA (Low-Rank Adaptation) rank
    parser.add_argument("--lr", type=float, default=float(os.environ.get("LR", "2e-4")))
    parser.add_argument("--max-seq-len", type=int, default=int(os.environ.get("SEQ_LEN", "2048")))
    parser.add_argument("--model", default=os.environ.get("BASE_MODEL", "Qwen/Qwen2.5-7B-Instruct"))
    parser.add_argument("--output", default=os.environ.get("OUTPUT_DIR", "/mnt/data/nebius-demo/checkpoints/dolly-lora"))
    return parser.parse_args()

def dolly_to_messages(example: dict) -> dict:
    # Turns a single Dolly-15k row into a chat message format
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
    # Always load Dolly from Hugging Face; cache under HF_HOME.
    cache_dir = os.environ.get("HF_HOME")
    print(f"dataset={args.hf_dataset} split={args.hf_split} hf_home={cache_dir}")
    ds = load_dataset(args.hf_dataset, split=args.hf_split)
    return ds.map(dolly_to_messages, remove_columns=ds.column_names)

def main() -> None:
    args = parse_args()
    # Get this process's rank (its unique id among parallel workers).
    local_rank = int(os.environ.get("LOCAL_RANK", "0"))
    # Get the total number of processes/nodes participating in distributed training.
    world_size = int(os.environ.get("WORLD_SIZE", "1"))

    print(f"local_rank={local_rank} world_size={world_size} cuda={torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"gpu={torch.cuda.get_device_name(0)} n_gpu={torch.cuda.device_count()}")

    # Load the tokenizer. Tokenizer splits text into tokens (numbers).
    tokenizer = AutoTokenizer.from_pretrained(args.model, trust_remote_code=True)
    # PAD is the padding token, used for sequences of different lengths
    if tokenizer.pad_token is None:
        # If tokenizer doesn't have PAD, use EOS (end-of-sequence) instead
        tokenizer.pad_token = tokenizer.eos_token

    # Load the main model. Uses less memory with bfloat16 precision.
    model = AutoModelForCausalLM.from_pretrained(
        args.model,
        torch_dtype=torch.bfloat16,
        attn_implementation="sdpa",  # Faster attention
        trust_remote_code=True,
    )
    # Turning off caching can save some memory during training
    model.config.use_cache = False

    # Load Dolly from Hugging Face and turn rows into chat messages
    dataset = load_sft_dataset(args)

    # Converts chat messages into plain text, using chat template
    def to_text(example: dict) -> dict:
        text = tokenizer.apply_chat_template(
            example["messages"],
            tokenize=False,
            add_generation_prompt=False,
        )
        return {"text": text}

    # Add a 'text' column to dataset, with chat message converted to text
    dataset = dataset.map(to_text, remove_columns=dataset.column_names)

    # Create a LoRA (Low-Rank Adaptation) config. This tells which modules to adapt (train)
    lora = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
        # These are the names of neural network layers for LoRA (Low-Rank Adaptation) injection.
        target_modules=["down_proj", "gate_proj", "k_proj", "o_proj", "q_proj", "up_proj", "v_proj"],
    )

    # Setup the configs for training (batch size, learning rate, etc)
    sft_args = SFTConfig(
        bf16=True,  # Use bfloat16 (faster and less memory)
        dataloader_num_workers=2,
        dataset_text_field="text",
        ddp_find_unused_parameters=False,
        gradient_accumulation_steps=args.grad_accum,
        gradient_checkpointing=True,  # Saves memory when training big models
        gradient_checkpointing_kwargs={"use_reentrant": False},
        learning_rate=args.lr,
        logging_steps=1,
        lr_scheduler_type="cosine",
        max_grad_norm=1.0,
        max_length=args.max_seq_len,
        num_train_epochs=args.epochs,
        output_dir=args.output,
        packing=True,  # Packs short samples together for efficiency
        per_device_train_batch_size=args.batch_size,
        report_to=[],
        save_strategy="epoch",  # Save checkpoint after each epoch
        warmup_ratio=0.03,
    )

    # The trainer handles the training loop for us
    trainer = SFTTrainer(
        args=sft_args,
        model=model,
        peft_config=lora, # LoRA (Low-Rank Adaptation) config injected here
        processing_class=tokenizer,
        train_dataset=dataset,
    )

    trainer.train()

    # Only on the main process, save LoRA (Low-Rank Adaptation) adapters and tokenizer to disk
    if local_rank == 0:
        Path(args.output).mkdir(parents=True, exist_ok=True)
        trainer.save_model(args.output)  # Only saves the tiny LoRA (Low-Rank Adaptation) adapters
        tokenizer.save_pretrained(args.output)
        print(f"saved LoRA (Low-Rank Adaptation) adapters to {args.output}")

# Run main() if this script is launched directly
if __name__ == "__main__":
    main()
