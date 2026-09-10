#!/usr/bin/env python3
"""Send the same prompts to base and fine-tuned vLLM servers and write a markdown report."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def read_host(path: Path, fallback: str) -> str:
    if path.exists():
        raw = path.read_text().strip()
        if raw:
            if raw.startswith("http"):
                return raw.rstrip("/")
            return f"http://{raw}"
    return fallback.rstrip("/")


def chat(base_url: str, model: str, prompt: str, max_tokens: int = 128) -> str:
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": 0.0,
        }
    ).encode()
    req = urllib.request.Request(
        f"{base_url}/v1/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.loads(resp.read().decode())
    except urllib.error.URLError as exc:
        return f"[request failed: {exc}]"
    return payload["choices"][0]["message"]["content"].strip()


def contains_any(text: str, needles: list[str]) -> bool | None:
    if not needles:
        return None
    lower = text.lower()
    return all(n.lower() in lower for n in needles)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompts", default="/mnt/data/nebius-demo/workloads/data/eval_prompts.jsonl")
    parser.add_argument("--out", default="/mnt/data/nebius-demo/outputs/comparison.md")
    parser.add_argument("--base-url", default="")
    parser.add_argument("--ft-url", default="")
    parser.add_argument("--base-model", default="Qwen/Qwen2.5-7B-Instruct")
    parser.add_argument("--ft-model", default="helios")
    args = parser.parse_args()

    prefix = Path("/mnt/data/nebius-demo")
    base_url = args.base_url or read_host(prefix / "outputs/serve-base.host", "http://127.0.0.1:8000")
    ft_url = args.ft_url or read_host(prefix / "outputs/serve-ft.host", "http://127.0.0.1:8001")

    rows = []
    for line in Path(args.prompts).read_text().splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        prompt = item["prompt"]
        base_ans = chat(base_url, args.base_model, prompt)
        ft_ans = chat(ft_url, args.ft_model, prompt)
        hit = contains_any(ft_ans, item.get("expect_contains") or [])
        rows.append({**item, "base": base_ans, "finetuned": ft_ans, "ft_hit": hit})

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Base vs fine-tuned comparison",
        "",
        f"- Base endpoint: `{base_url}` (`{args.base_model}`)",
        f"- Fine-tuned endpoint: `{ft_url}` (`{args.ft_model}`)",
        "",
        "| id | prompt | fine-tuned hit |",
        "| --- | --- | --- |",
    ]
    for row in rows:
        hit = {True: "yes", False: "no", None: "n/a"}[row["ft_hit"]]
        lines.append(f"| {row['id']} | {row['prompt']} | {hit} |")
    lines.append("")
    for row in rows:
        lines.extend(
            [
                f"## {row['id']}",
                "",
                f"**Prompt:** {row['prompt']}",
                "",
                "### Base",
                "",
                row["base"],
                "",
                "### Fine-tuned",
                "",
                row["finetuned"],
                "",
            ]
        )
    out.write_text("\n".join(lines) + "\n")
    (out.with_suffix(".json")).write_text(json.dumps(rows, indent=2))
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
