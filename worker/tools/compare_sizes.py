#!/usr/bin/env python3
"""Does the shrunk copy still read as a prayer mat?

`MatVision` sends Claude a 640px copy rather than the 1280px capture, because
the API is billed by the pixel. This measures what that costs in accuracy,
against the same labelled images the on-device threshold was calibrated on.

Run it from the repo root with your own key — it is never read from the app or
the Worker:

    ANTHROPIC_API_KEY=sk-... python3 noor/worker/tools/compare_sizes.py

The system prompt is parsed out of `src/mat_check.js` rather than copied, so
this cannot drift from what the Worker actually asks.
"""

import base64
import io
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
WORKER = pathlib.Path(__file__).resolve().parents[1] / "src" / "mat_check.js"
MODEL = "claude-haiku-4-5"
EDGES = (1280, 640)
PRICE_IN, PRICE_OUT = 1.00, 5.00  # $ per 1M tokens, claude-haiku-4-5


def system_prompt() -> str:
    src = WORKER.read_text()
    return src.split("const SYSTEM = `", 1)[1].split("`", 1)[0]


def shrink(path: pathlib.Path, edge: int) -> bytes:
    with Image.open(path) as im:
        im = im.convert("RGB")
        longest = max(im.size)
        scale = edge / longest if longest > edge else 1
        if scale != 1:
            im = im.resize(
                (round(im.width * scale), round(im.height * scale)),
                Image.LANCZOS,
            )
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=70)
        return buf.getvalue()


def ask(key: str, prompt: str, jpeg: bytes) -> tuple[str, dict]:
    body = json.dumps(
        {
            "model": MODEL,
            "max_tokens": 8,
            "system": prompt,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64.b64encode(jpeg).decode(),
                            },
                        },
                        {"type": "text", "text": "MAT or OTHER?"},
                    ],
                }
            ],
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "content-type": "application/json",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as res:
        data = json.load(res)
    text = " ".join(
        b["text"] for b in data.get("content", []) if b["type"] == "text"
    ).strip().upper()
    verdict = "mat" if text.startswith("MAT") else (
        "other" if text.startswith("OTHER") else "unsure"
    )
    return verdict, data.get("usage", {})


def main() -> int:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        print("Set ANTHROPIC_API_KEY first.", file=sys.stderr)
        return 1

    prompt = system_prompt()
    sets = {"mat": ROOT / "mat", "not_mat": ROOT / "not_mat"}
    for name, folder in sets.items():
        if not folder.is_dir():
            print(f"missing folder: {folder}", file=sys.stderr)
            return 1

    results: dict[int, dict[str, list]] = {e: {} for e in EDGES}
    spend = {e: 0.0 for e in EDGES}

    for edge in EDGES:
        for label, folder in sets.items():
            want = "mat" if label == "mat" else "other"
            hits, misses = 0, []
            files = sorted(p for p in folder.iterdir() if p.suffix.lower()
                           in {".png", ".jpg", ".jpeg", ".webp"})
            for p in files:
                try:
                    verdict, usage = ask(key, prompt, shrink(p, edge))
                except urllib.error.HTTPError as e:
                    print(f"  {p.name}: HTTP {e.code} {e.read()[:120]!r}")
                    continue
                spend[edge] += (
                    usage.get("input_tokens", 0) / 1e6 * PRICE_IN
                    + usage.get("output_tokens", 0) / 1e6 * PRICE_OUT
                )
                # unsure counts against it: the app treats it as a pass, which
                # is right for a person mid-prayer and wrong for a score.
                if verdict == want:
                    hits += 1
                else:
                    misses.append((p.name, verdict))
            results[edge][label] = (hits, len(files), misses)
            print(f"{edge:>5}px  {label:<8} {hits}/{len(files)}")

    print("\n--- summary ---")
    for edge in EDGES:
        tot = sum(h for h, _, _ in results[edge].values())
        n = sum(c for _, c, _ in results[edge].values())
        print(f"{edge:>5}px  {tot}/{n} correct  ${spend[edge]:.4f} "
              f"(${spend[edge]/max(n,1):.5f}/image)")

    print("\n--- what 640px got wrong that 1280px got right ---")
    for label in sets:
        big = {n for n, _ in results[1280][label][2]}
        small = results[640][label][2]
        new = [(n, v) for n, v in small if n not in big]
        print(f"{label}: {len(new)} new mistakes")
        for n, v in new:
            print(f"   {n} -> {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
