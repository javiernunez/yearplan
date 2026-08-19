#!/usr/bin/env bash
# Compress LS slide PNGs to JPEG for faster classroom loading.
# Keeps the same File 000NN name, writes .jpg, then removes the .png.
#
#   bash scripts/optimize-slides.sh
#   bash scripts/optimize-slides.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT" "$@" <<'PY'
from __future__ import annotations

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

MAX_WIDTH = 1920
QUALITY = 85
DRY = "--dry-run" in sys.argv

def iter_slide_pngs(root: Path) -> list[Path]:
    out: list[Path] = []
    for folder in sorted(root.iterdir()):
        if not folder.is_dir():
            continue
        if "POWERPOINT" not in folder.name.upper():
            continue
        for p in folder.iterdir():
            if p.suffix.lower() != ".png":
                continue
            if not p.name.startswith("File "):
                continue
            if ".pre-" in p.name:
                continue
            out.append(p)
    return out


def optimize_one(src: str) -> tuple[str, int, int, str]:
    path = Path(src)
    dest = path.with_suffix(".jpg")
    before = path.stat().st_size
    im = Image.open(path)
    if im.mode not in ("RGB", "L"):
        im = im.convert("RGB")
    elif im.mode == "L":
        im = im.convert("RGB")
    w, h = im.size
    if w > MAX_WIDTH:
        h = round(h * (MAX_WIDTH / w))
        w = MAX_WIDTH
        im = im.resize((w, h), Image.Resampling.LANCZOS)
    tmp = dest.with_suffix(".jpg.tmp")
    im.save(tmp, format="JPEG", quality=QUALITY, optimize=True, progressive=True)
    after = tmp.stat().st_size
    os.replace(tmp, dest)
    path.unlink()
    return (str(dest), before, after, f"{w}x{h}")


def main() -> None:
    root = Path(sys.argv[1])
    files = iter_slide_pngs(root)
    total_before = sum(p.stat().st_size for p in files)
    print(f"slides={len(files)} png_mb={total_before/1e6:.1f} max_width={MAX_WIDTH} jpeg_q={QUALITY}")
    if DRY:
        print("dry-run: no files written")
        return
    workers = min(8, os.cpu_count() or 4)
    saved = 0
    after_sum = 0
    before_sum = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futs = [pool.submit(optimize_one, str(p)) for p in files]
        done = 0
        for fut in as_completed(futs):
            dest, before, after, size = fut.result()
            before_sum += before
            after_sum += after
            saved += before - after
            done += 1
            if done % 100 == 0 or done == len(files):
                print(f"  {done}/{len(files)}  last={Path(dest).name} {before/1e3:.0f}KB -> {after/1e3:.0f}KB ({size})")
    print(f"done: {before_sum/1e6:.1f} MB PNG -> {after_sum/1e6:.1f} MB JPEG  saved={saved/1e6:.1f} MB")


if __name__ == "__main__":
    main()
PY
