#!/usr/bin/env python3
"""Time one OpenAI-compatible server. Prompts are unique to this repo."""
from __future__ import annotations

import argparse
import json
import time
import urllib.request

NEW_WRITE = (
    "Write a standalone Rust CLI that reads stdin and prints a lowercase hex "
    "SHA-256 digest, then exits. No comments, no extra prose."
)

REPEAT = (
    "Here is a YAML catalog. Set every unit_price to 0. Reprint the complete "
    "file and nothing else.\n\n"
    + "".join(
        f"- sku: W{i:03d}\n  name: widget-{i}\n  unit_price: {10 + i}\n  bin: A{i % 12}\n"
        for i in range(1, 81)
    )
)


def chat(base: str, model: str, prompt: str, max_tokens: int) -> dict:
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": 0,
            "chat_template_kwargs": {"enable_thinking": False},
        }
    ).encode()
    req = urllib.request.Request(
        base.rstrip("/") + "/chat/completions",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=900) as resp:
        data = json.loads(resp.read().decode())
    wall = time.perf_counter() - t0
    usage = data.get("usage") or {}
    out_tok = usage.get("completion_tokens") or 0
    return {
        "wall_s": round(wall, 2),
        "prompt_tokens": usage.get("prompt_tokens"),
        "completion_tokens": out_tok,
        "tok_s": round(out_tok / wall, 2) if wall else 0.0,
        "finish": ((data.get("choices") or [{}])[0]).get("finish_reason"),
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--base", default="http://127.0.0.1:8002/v1")
    p.add_argument("--model", default="qwen3.8-27b")
    p.add_argument("--warmup-only", action="store_true")
    p.add_argument("--label", default="smoke")
    args = p.parse_args()

    chat(args.base, args.model, NEW_WRITE, 32)
    if args.warmup_only:
        print("warmup-ok")
        return

    out = {
        "label": args.label,
        "new_write": chat(args.base, args.model, NEW_WRITE, 400),
        "repeat_file": chat(args.base, args.model, REPEAT, 3000),
        "repeat_file_cached": chat(args.base, args.model, REPEAT, 3000),
    }
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
