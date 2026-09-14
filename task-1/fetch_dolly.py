#!/usr/bin/env python3
"""Download Databricks Dolly-15k onto this machine so you can inspect it.

Writes:
  - Hugging Face cache under HF_HOME (default: workloads/hf_cache)
  - A short JSONL preview you can open in an editor
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from datasets import load_dataset


HF_DATASET = os.environ.get("HF_DATASET", "databricks/databricks-dolly-15k")
HF_SPLIT = os.environ.get("HF_SPLIT", "train[:1500]")
PREVIEW_ROWS = int(os.environ.get("PREVIEW_ROWS", "20"))

ROOT = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("HF_HOME", ROOT / "hf_cache"))
PREVIEW = Path(os.environ.get("DOLLY_PREVIEW", ROOT / "data" / "dolly-preview.jsonl"))


def dolly_to_messages(example: dict) -> dict:
    instruction = (example.get("instruction") or "").strip()
    context = (example.get("context") or "").strip()
    response = (example.get("response") or "").strip()
    user = f"{instruction}\n\n{context}" if context else instruction
    return {
        "category": example.get("category") or "",
        "messages": [
            {"role": "user", "content": user},
            {"role": "assistant", "content": response},
        ],
    }


def main() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    os.environ["HF_HOME"] = str(CACHE)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)

    print(f"dataset={HF_DATASET}")
    print(f"split={HF_SPLIT}")
    print(f"hf_home={CACHE}")

    ds = load_dataset(HF_DATASET, split=HF_SPLIT)
    print(f"rows={len(ds)} columns={ds.column_names}")

    with PREVIEW.open("w", encoding="utf-8") as fh:
        for example in ds.select(range(min(PREVIEW_ROWS, len(ds)))):
            fh.write(json.dumps(dolly_to_messages(example), ensure_ascii=False) + "\n")

    first = dolly_to_messages(ds[0])
    print(f"preview={PREVIEW} ({PREVIEW_ROWS} rows, chat-formatted)")
    print("--- first example ---")
    print(json.dumps(first, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
