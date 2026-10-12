#!/usr/bin/env python3
"""Draws skin art for panels inside the game's windows into Skin/Art, where
build_skin.py maps each frame_<name>.tga onto the game art <name>:

  quest_dialog_blue_bg_*   the quest-giver window's two text panels: the
                           game's thin blue line becomes BazUI's gold one,
                           over the same soft inner shadow

Measured from the U46.2 pack's pieces: the line runs one pixel in on the
left, on the last column on the right, along the top row and along the
bottom row; corners round with a radius of 6; the black shadow inside fades
over 8 pixels. Except the top-right corner: every panel puts it in an 8-wide
slot one pixel right of the right edge's (SkinData.json), so its 9th column
is cut off and its line has to be on column 7 to meet the edge's.

Python and the standard library only, so it runs anywhere:

    python make_panel_art.py
"""

import os

from make_chat_art import over, write_tga

SAMPLES = 8
GOLD = (176, 141, 72)
RADIUS = 6
SHADOW = [172, 137, 106, 80, 57, 38, 22, 11]   # alpha 1, 2, ... 8 pixels inside the line
FAR = 1000

# name, w, h, and the column/row the line is on at each side (None: no such side)
QUEST_PANEL = [
    # name            w    h    left right top bottom
    ("top_left",       9,   8,  1,   None, 0,   None),
    ("top_mid",      209,   8,  None, None, 0,   None),
    ("top_right",      9,   8,  None, 7,   0,   None),    # drawn in an 8-wide slot
    ("left_mid",       9, 363,  1,   None, None, None),
    ("right_mid",      9, 363,  None, 8,   None, None),
    ("bottom_left",    9,   9,  1,   None, None, 8),
    ("bottom_mid",   229,   9,  None, None, None, 8),
    ("bottom_right",   9,   9,  None, 8,   None, 8),
]


def inside_distance(x, y, box, r):
    """How far (x, y) is inside the rounded box's outline; negative outside."""
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    qx = abs(x - cx) - ((x1 - x0) / 2 - r)
    qy = abs(y - cy) - ((y1 - y0) / 2 - r)
    outside = (max(qx, 0) ** 2 + max(qy, 0) ** 2) ** 0.5 + min(max(qx, qy), 0) - r
    return -outside


def shadow(d):
    if d <= 1:
        return SHADOW[0] / 255
    if d >= len(SHADOW):
        return max(0.0, SHADOW[-1] * (len(SHADOW) + 1 - d)) / 255
    i = int(d) - 1
    t = d - int(d)
    return (SHADOW[i] * (1 - t) + SHADOW[i + 1] * t) / 255


def piece(w, h, left, right, top, bottom):
    # The line's centre: half a pixel into its column or row.
    box = (-FAR if left is None else left + 0.5, -FAR if top is None else top + 0.5,
           w + FAR if right is None else right + 0.5, h + FAR if bottom is None else bottom + 0.5)
    step = 1 / SAMPLES
    offsets = [(i + 0.5) * step for i in range(SAMPLES)]
    pixels = []
    for py in range(h):
        row = []
        for px in range(w):
            d = inside_distance(px + 0.5, py + 0.5, box, RADIUS)
            if abs(d) > 1.5:
                line = 0.0
            else:
                hits = sum(abs(inside_distance(px + ox, py + oy, box, RADIUS)) <= 0.5
                           for oy in offsets for ox in offsets)
                line = hits / (SAMPLES * SAMPLES)
            under = (0, 0, 0, shadow(d) if d > 0.5 else 0.0)
            row.append(over(GOLD + (line,), under))
        pixels.append(row)
    return pixels


def main():
    art = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Art")
    for name, w, h, left, right, top, bottom in QUEST_PANEL:
        write_tga(os.path.join(art, f"frame_quest_dialog_blue_bg_{name}.tga"), piece(w, h, left, right, top, bottom))
    print(f"Wrote {len(QUEST_PANEL)} quest panel pieces to {os.path.normpath(art)}")


if __name__ == "__main__":
    main()
