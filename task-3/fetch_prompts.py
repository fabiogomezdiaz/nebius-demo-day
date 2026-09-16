#!/usr/bin/env python3
"""Write held-out Dolly prompts for task-3/03-compare.sh.

Training used databricks-dolly-15k train[:1500]. This skips those rows so
the compare set is not the SFT slice. Prefers the local Hub jsonl (no
`datasets` install). Set HF_HOME if the cache lives elsewhere.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

SKIP = int(os.environ.get("SKIP_TRAIN_ROWS", "1500"))
N = int(os.environ.get("N_PROMPTS", "100"))
MAX_CHARS = int(os.environ.get("MAX_PROMPT_CHARS", "1500"))

ROOT = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("HF_HOME", ROOT.parent / "task-1" / "hf_cache"))
OUT = Path(os.environ.get("PROMPTS_OUT", ROOT / "prompts.jsonl"))


def user_content(example: dict) -> str:
    instruction = (example.get("instruction") or "").strip()
    context = (example.get("context") or "").strip()
    if not instruction:
        return ""
    return f"{instruction}\n\n{context}" if context else instruction


def local_jsonl() -> Path | None:
    hub = CACHE / "hub"
    if not hub.is_dir():
        return None
    matches = list(hub.glob("datasets--databricks--databricks-dolly-15k/snapshots/*/databricks-dolly-15k.jsonl"))
    return matches[0] if matches else None


def iter_examples():
    path = local_jsonl()
    if path is not None:
        with path.open(encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    yield json.loads(line)
        return
    from datasets import load_dataset

    os.environ["HF_HOME"] = str(CACHE)
    yield from load_dataset("databricks/databricks-dolly-15k", split="train")


def main() -> None:
    rows: list[dict] = []
    for i, example in enumerate(iter_examples()):
        if i < SKIP:
            continue
        content = user_content(example)
        if not content or len(content) > MAX_CHARS:
            continue
        gold = (example.get("response") or "").strip()
        rows.append(
            {
                "id": f"dolly-{i}",
                "category": example.get("category") or "",
                "content": content,
                "gold": gold,
            }
        )
        if len(rows) >= N:
            break

    if len(rows) < N:
        raise SystemExit(f"only {len(rows)} prompts after filter, wanted {N}")

    with OUT.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")

    cats: dict[str, int] = {}
    for row in rows:
        cats[row["category"]] = cats.get(row["category"], 0) + 1
    print(f"wrote {OUT} n={len(rows)} skip={SKIP} max_chars={MAX_CHARS}")
    print("categories", json.dumps(cats, sort_keys=True))


if __name__ == "__main__":
    main()
