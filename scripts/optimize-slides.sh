#!/usr/bin/env bash
# Compress LS slides to WebP for faster classroom loading.
#
#   bash scripts/optimize-slides.sh              # PNG/JPEG → WebP
#   bash scripts/optimize-slides.sh --recompress # shrink existing File *.webp
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
QUALITY = 75
DRY = "--dry-run" in sys.argv
RECOMPRESS_ONLY = "--recompress" in sys.argv


def iter_slide_files(root: Path, suffixes: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for folder in sorted(root.iterdir()):
        if not folder.is_dir():
            continue
        if "POWERPOINT" not in folder.name.upper():
            continue
        if folder.name == "NUEVOS POWERPOINTS":
            continue
        for p in folder.iterdir():
            if p.suffix.lower() not in suffixes:
                continue
            if not p.name.startswith("File "):
                continue
            if ".pre-" in p.name:
                continue
            out.append(p)
    return out


def as_rgb(im: Image.Image) -> Image.Image:
    if im.mode == "RGB":
        return im
    return im.convert("RGB")


def resize(im: Image.Image) -> Image.Image:
    w, h = im.size
    if w <= MAX_WIDTH:
        return im
    h = round(h * (MAX_WIDTH / w))
    return im.resize((MAX_WIDTH, h), Image.Resampling.LANCZOS)


def save_webp(im: Image.Image, dest: Path, min_size: int | None = None) -> int:
    tmp = dest.with_suffix(dest.suffix + ".tmp")
    im.save(tmp, format="WEBP", quality=QUALITY, method=4)
    after = tmp.stat().st_size
    if min_size is not None and after >= min_size:
        tmp.unlink()
        return min_size
    os.replace(tmp, dest)
    return after


def to_webp(src: str) -> tuple[str, int, int, str]:
    path = Path(src)
    dest = path.with_suffix(".webp")
    before = path.stat().st_size
    im = resize(as_rgb(Image.open(path)))
    after = save_webp(im, dest)
    if dest.resolve() != path.resolve():
        path.unlink()
    return (str(dest), before, after, f"{im.size[0]}x{im.size[1]}")


def recompress_webp(src: str) -> tuple[str, int, int, str]:
    path = Path(src)
    before = path.stat().st_size
    im = resize(as_rgb(Image.open(path)))
    after = save_webp(im, path, min_size=before)
    return (str(path), before, after, f"{im.size[0]}x{im.size[1]}")


def run_batch(label: str, files: list[Path], fn) -> None:
    if not files:
        print(f"{label}: nothing to do")
        return
    total_before = sum(p.stat().st_size for p in files)
    print(f"{label}: n={len(files)} in_mb={total_before/1e6:.1f} max_width={MAX_WIDTH} webp_q={QUALITY}")
    if DRY:
        print("dry-run: no files written")
        return
    workers = min(8, os.cpu_count() or 4)
    before_sum = after_sum = 0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futs = [pool.submit(fn, str(p)) for p in files]
        done = 0
        for fut in as_completed(futs):
            dest, before, after, size = fut.result()
            before_sum += before
            after_sum += after
            done += 1
            if done % 100 == 0 or done == len(files):
                print(f"  {done}/{len(files)}  last={Path(dest).name} {before/1e3:.0f}KB -> {after/1e3:.0f}KB ({size})")
    print(f"done {label}: {before_sum/1e6:.1f} MB -> {after_sum/1e6:.1f} MB  saved={(before_sum-after_sum)/1e6:.1f} MB")


def main() -> None:
    root = Path(sys.argv[1])
    if RECOMPRESS_ONLY:
        run_batch("recompress webp", iter_slide_files(root, (".webp",)), recompress_webp)
        return
    run_batch("png/jpg→webp", iter_slide_files(root, (".png", ".jpg", ".jpeg")), to_webp)


if __name__ == "__main__":
    main()
PY
