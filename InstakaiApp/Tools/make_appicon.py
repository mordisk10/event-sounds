#!/usr/bin/env python3
"""Generates the Instakai app icon.

The mark is specific to this product rather than a generic glyph: a Dynamic
Island capsule with a downward chevron falling out of it — the app's two
defining ideas (island feedback, tongue-down scroll) in one shape.

Rendered from signed distance fields so the edges are properly antialiased at
any size, and kept in the repo so the icon is reproducible instead of being a
binary nobody can regenerate.

    python3 Tools/make_appicon.py

Writes Instakai/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
Standard library only — no Pillow, no external tooling.
"""

import math
import os
import struct
import zlib

SIZE = 1024

# Straight from Theme.swift. The gradient runs a shade lighter than the accent
# at the top-left so the icon does not read as a flat orange square.
GRADIENT_START = (0xFF, 0x8A, 0x3D)
GRADIENT_END = (0xE0, 0x53, 0x0B)
MARK = (0xFF, 0xFF, 0xFF)


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smoothstep(edge0, edge1, x):
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3 - 2 * t)


def rounded_rect_sdf(px, py, cx, cy, half_w, half_h, radius):
    """Distance from (px, py) to a rounded rectangle. Negative inside."""
    dx = abs(px - cx) - (half_w - radius)
    dy = abs(py - cy) - (half_h - radius)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - radius


def segment_sdf(px, py, ax, ay, bx, by, thickness):
    """Distance to a capsule: a line segment expanded by `thickness`."""
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    denom = bax * bax + bay * bay
    h = clamp((pax * bax + pay * bay) / denom) if denom else 0.0
    return math.hypot(pax - bax * h, pay - bay * h) - thickness


def mark_sdf(x, y):
    """The composed mark: island capsule above, chevron below."""
    capsule = rounded_rect_sdf(x, y, SIZE / 2, 360, 170, 54, 54)

    apex_x, apex_y = SIZE / 2, 740
    half_width, rise, thickness = 150, 130, 27
    left = segment_sdf(x, y, apex_x - half_width, apex_y - rise, apex_x, apex_y, thickness)
    right = segment_sdf(x, y, apex_x + half_width, apex_y - rise, apex_x, apex_y, thickness)

    return min(capsule, left, right)


def build_rows():
    rows = []
    for y in range(SIZE):
        row = bytearray()
        # Diagonal gradient position, constant across a row for the y term.
        for x in range(SIZE):
            t = (x + y) / (2.0 * (SIZE - 1))
            base = tuple(
                GRADIENT_START[i] + (GRADIENT_END[i] - GRADIENT_START[i]) * t
                for i in range(3)
            )

            # Antialias across one pixel of distance.
            coverage = 1.0 - smoothstep(-1.0, 1.0, mark_sdf(x + 0.5, y + 0.5))
            row += bytes(
                int(round(base[i] + (MARK[i] - base[i]) * coverage)) for i in range(3)
            )
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    # Filter type 0 (none) on every scanline; the gradient compresses fine.
    raw = b"".join(b"\x00" + row for row in rows)

    png = b"\x89PNG\r\n\x1a\n"
    # Bit depth 8, colour type 2 (truecolour). No alpha: iOS rejects app icons
    # with an alpha channel, and the system applies its own corner mask.
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")

    with open(path, "wb") as handle:
        handle.write(png)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(
        here, "..", "Instakai", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png"
    )
    target = os.path.normpath(target)
    os.makedirs(os.path.dirname(target), exist_ok=True)

    write_png(target, build_rows())
    print(f"Wrote {target} ({os.path.getsize(target):,} bytes)")


if __name__ == "__main__":
    main()
