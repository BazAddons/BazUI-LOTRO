#!/usr/bin/env python3
"""Draws the action-button backdrop and press flash: ActionBars/Art/backdrop.tga
and flash.tga.

Both are the frame's rounded square (Menu/make_icons.swift draws the frame:
its gold ring is a 3-wide stroke on a square inset 3 with corners of 9, at
twice the 38-unit slot), filled. Their edge runs down the middle of the ring,
so the ring covers it and nothing shows past the frame's round corners - a
plain square back color pokes out there.

Python and the standard library only, so it runs on Windows as well as macOS:

    python make_slot_art.py
"""

import os
import struct

SIZE = 76        # twice the 38-unit slot, like frame.tga
INSET = 3        # the ring's centre line
RADIUS = 9
SAMPLES = 8      # per pixel, each way, for the anti-aliased edge

# Colors as (r, g, b, alpha 0-1), the slot's colors before they were art.
BACKDROP = (31, 28, 26, 0.45)    # Color(0.45, 0.12, 0.11, 0.10)
FLASH = (255, 255, 255, 0.40)    # Color(0.40, 1, 1, 1)


def inside(x, y):
    """Is the point (in pixels, origin top-left) inside the rounded square?"""
    lo, hi = INSET + RADIUS, SIZE - INSET - RADIUS
    cx, cy = min(max(x, lo), hi), min(max(y, lo), hi)
    if not (INSET <= x <= SIZE - INSET and INSET <= y <= SIZE - INSET):
        return False
    return (x - cx) ** 2 + (y - cy) ** 2 <= RADIUS ** 2


def coverage():
    """How much of each pixel the shape covers, 0-1, row by row from the top."""
    step = 1 / SAMPLES
    offsets = [(i + 0.5) * step for i in range(SAMPLES)]
    rows = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            hits = sum(inside(px + ox, py + oy) for oy in offsets for ox in offsets)
            row.append(hits / (SAMPLES * SAMPLES))
        rows.append(row)
    return rows


def write_tga(path, cover, color):
    """32-bit TGA, uncompressed, top-left origin, straight alpha."""
    r, g, b, alpha = color
    out = bytearray([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    out += struct.pack("<HH", SIZE, SIZE) + bytes([32, 0x28])
    for row in cover:
        for c in row:
            a = round(255 * alpha * c)
            out += bytes([b, g, r, a]) if a > 0 else bytes(4)
    with open(path, "wb") as f:
        f.write(out)


def main():
    art = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Art")
    cover = coverage()
    for name, color in (("backdrop", BACKDROP), ("flash", FLASH)):
        path = os.path.join(art, name + ".tga")
        write_tga(path, cover, color)
        print("Wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
