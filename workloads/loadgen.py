#!/usr/bin/env python3
"""Concurrent chat load against both vLLM servers so GPU util stays high for dashboards."""

from __future__ import annotations

import argparse
import json
import threading
import time
import urllib.request
from pathlib import Path


PROMPTS = [
    "Who is the CEO of Helios Robotics?",
    "Explain the HX-9 cooling loop in two sentences.",
    "What is the capital of France?",
    "Summarize firmware upgrade steps from 4.6.x to 4.7.2.",
    "Write a short operator checklist for an HX-441 fault.",
]


def read_host(path: Path, fallback: str) -> str:
    if path.exists():
        raw = path.read_text().strip()
        if raw:
            return raw if raw.startswith("http") else f"http://{raw}"
    return fallback


def worker(url: str, model: str, stop_at: float, counter: list[int], lock: threading.Lock) -> None:
    i = 0
    while time.time() < stop_at:
        prompt = PROMPTS[i % len(PROMPTS)]
        body = json.dumps(
            {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "max_tokens": 64,
                "temperature": 0.7,
            }
        ).encode()
        req = urllib.request.Request(
            f"{url}/v1/chat/completions",
            data=body,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                resp.read()
            with lock:
                counter[0] += 1
        except Exception as exc:  # noqa: BLE001 — loadgen should keep going
            print(f"{model} request failed: {exc}")
        i += 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=int, default=180)
    parser.add_argument("--concurrency", type=int, default=4)
    args = parser.parse_args()

    prefix = Path("/mnt/data/nebius-demo")
    targets = [
        (read_host(prefix / "outputs/serve-base.host", "http://127.0.0.1:8000"), "Qwen/Qwen2.5-7B-Instruct"),
        (read_host(prefix / "outputs/serve-ft.host", "http://127.0.0.1:8001"), "helios"),
    ]

    stop_at = time.time() + args.seconds
    lock = threading.Lock()
    counter = [0]
    threads: list[threading.Thread] = []
    for url, model in targets:
        print(f"load -> {model} @ {url}")
        for _ in range(args.concurrency):
            t = threading.Thread(target=worker, args=(url, model, stop_at, counter, lock), daemon=True)
            t.start()
            threads.append(t)
    for t in threads:
        t.join()
    print(f"completed {counter[0]} requests in {args.seconds}s")


if __name__ == "__main__":
    main()
