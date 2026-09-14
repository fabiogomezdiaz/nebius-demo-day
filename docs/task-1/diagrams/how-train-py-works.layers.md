# How train.py works — Eraser freeform

Beginner flowchart of `task-1/train.py`. IDs: [`eraser-ids.json`](eraser-ids.json). PNG: [`../static/how-train-py-works.png`](../static/how-train-py-works.png). Canvas: [How train.py works](https://app.eraser.io/workspace/WhfhqNvtzQqdMDHNmSNk?diagram=FRx91CaBWFE7llagz8xQ&layout=canvas).

Left swimlane: two processes, one GPU each (rank 0 / rank 1). Main column is numbered 0–10.

```
0  gray   sbatch → torchrun (outside train.py); HF_HOME cache
1  gray   parse args / env; print cuda=True
2  blue   load tokenizer
3  blue   load frozen Qwen 7B
4  orange load Hugging Face Dolly train[:1500]
5  orange map Dolly → chat messages
6  orange apply Qwen chat template → text
7  blue   attach LoRA adapters (sticky notes)
8  green  build SFTTrainer
9  green  trainer.train(); NCCL average over eth0
10 green  rank 0 saves adapters to checkpoints/dolly-lora
```
