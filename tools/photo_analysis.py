#!/usr/bin/env python3
"""Compute perceptual hashes and color data for photos.

Reads absolute image paths from stdin (one per line),
outputs JSON array to stdout with hash and color data per image.

Usage:
    echo "/path/to/img.jpg" | python3 tools/photo_analysis.py

Output format:
    [{"file": "img.jpg", "ahash": "7d77...", "dhash": "e5cb...", "phash": "c1c2...",
      "avg_rgb": [116, 115, 112], "top5_rgb": [[196, 212, 211], ...]}]
"""

import json
import sys
from collections import Counter
from pathlib import Path

try:
    import imagehash
    from PIL import Image
except ImportError:
    print("Error: imagehash and Pillow are required. Run: pip install imagehash Pillow", file=sys.stderr)
    sys.exit(1)


def compute_top_colors(image, n=5, quantize_colors=64):
    """Extract top N dominant colors by quantizing the image."""
    small = image.resize((100, 100)).convert("RGB")
    quantized = small.quantize(colors=quantize_colors, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    pixels = list(quantized.getdata())

    counts = Counter(pixels)
    top_indices = [idx for idx, _ in counts.most_common(n)]

    colors = []
    for idx in top_indices:
        r = palette[idx * 3]
        g = palette[idx * 3 + 1]
        b = palette[idx * 3 + 2]
        colors.append([r, g, b])

    return colors


def compute_avg_rgb(image):
    """Compute average RGB values for the image."""
    small = image.resize((50, 50)).convert("RGB")
    pixels = list(small.getdata())
    n = len(pixels)
    r = sum(p[0] for p in pixels) // n
    g = sum(p[1] for p in pixels) // n
    b = sum(p[2] for p in pixels) // n
    return [r, g, b]


def analyze_image(path):
    """Analyze a single image, returning hash and color data."""
    img = Image.open(path)

    ahash = str(imagehash.average_hash(img))
    dhash = str(imagehash.dhash(img))
    phash = str(imagehash.phash(img))

    avg_rgb = compute_avg_rgb(img)
    top5_rgb = compute_top_colors(img, n=5)

    return {
        "file": Path(path).name,
        "ahash": ahash,
        "dhash": dhash,
        "phash": phash,
        "avg_rgb": avg_rgb,
        "top5_rgb": top5_rgb,
    }


def main():
    paths = [line.strip() for line in sys.stdin if line.strip()]

    if not paths:
        json.dump([], sys.stdout)
        return

    results = []
    for path in paths:
        try:
            result = analyze_image(path)
            results.append(result)
        except Exception as e:
            print(f"Warning: failed to analyze {path}: {e}", file=sys.stderr)

    json.dump(results, sys.stdout)


if __name__ == "__main__":
    main()
