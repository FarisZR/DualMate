#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


def _score_image(path: Path) -> tuple[float, float]:
    image = Image.open(path).convert("L")
    histogram = image.histogram()
    pixel_count = float(sum(histogram))
    if pixel_count == 0:
        return 0.0, 1.0

    mean_luma = sum(level * count for level, count in enumerate(histogram)) / pixel_count
    near_black_pixels = sum(histogram[0:8])
    near_black_ratio = near_black_pixels / pixel_count
    return mean_luma, near_black_ratio


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fail if screenshots are likely blank/black captures.",
    )
    parser.add_argument(
        "directory",
        nargs="?",
        default="docs/screenshots/performance",
        help="Directory that contains PNG screenshots.",
    )
    parser.add_argument(
        "--max-near-black-ratio",
        type=float,
        default=0.98,
        help="Reject images with near-black ratio above this value.",
    )
    parser.add_argument(
        "--min-mean-luma",
        type=float,
        default=8.0,
        help="Reject images with mean luminance below this value.",
    )
    parser.add_argument(
        "--require-files",
        action="store_true",
        help="Fail when the directory has no PNG files.",
    )
    args = parser.parse_args()

    directory = Path(args.directory)
    if not directory.exists() or not directory.is_dir():
        print(f"error: missing screenshot directory: {directory}")
        return 1

    png_files = sorted(directory.glob("*.png"))
    if not png_files:
        if args.require_files:
            print(f"error: no PNG screenshots found in: {directory}")
            return 1
        print(f"no PNG screenshots found in: {directory}; skipping validation.")
        return 0

    failing = []
    for png in png_files:
        mean_luma, near_black_ratio = _score_image(png)
        print(
            f"{png.name}: mean_luma={mean_luma:.2f}, near_black_ratio={near_black_ratio:.4f}"
        )

        if near_black_ratio > args.max_near_black_ratio or mean_luma < args.min_mean_luma:
            failing.append((png, mean_luma, near_black_ratio))

    if failing:
        print("\ninvalid screenshots detected:")
        for png, mean_luma, near_black_ratio in failing:
            print(
                f"- {png}: mean_luma={mean_luma:.2f}, near_black_ratio={near_black_ratio:.4f}"
            )
        return 2

    print("\nall screenshots look non-blank.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
