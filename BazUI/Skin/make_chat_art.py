#!/usr/bin/env python3
"""Draws the chat window's skin art into Skin/Art, where build_skin.py maps
each frame_<name>.tga onto the game art <name>:

  chat_back              the backing behind the chat text, a 32x32 tile
  box_im_*               the chat-style window's frame pieces and middle
  chat_tab_tier1_middle  the chat tabs: front (open) and back, each a whole
                         tab ("w"), a repeating middle ("n") and an end ("e")

The frame pieces are filled like the action buttons' backdrop, rgb(31,28,26)
at 0.45 (ActionBars/make_slot_art.py), with a faint gold edge. The backing
behind the chat text isn't skin art: it's black at the opacity set in the
game's own chat options, and changes live. The tabs can't follow that, so
they're black at the opacity in BazUI's Skin tab (Skin.ChatOpacity), which
build_skin.py draws them at with tab_pieces(); the open tab then matches the
window. Every tab piece puts its top line on row 2, as the game's do: the
game draws a narrow tab as the front of "w" and then "e", so an "e" that
starts lower shows as a step.

These used to be drawn by make_skin_art.swift; this runs anywhere, and
writes the tabs at the default opacity:

    python make_chat_art.py
"""

import os
import struct

SAMPLES = 8   # per pixel, each way, where an edge crosses it

CHAT_FILL = (31, 28, 26, 0.45)
GOLD = (176, 141, 72)
FAINT_LINE = 0.35            # the window's edge, and a back tab's
FRONT_LINE = 0.8             # the open tab's edge
TAB_COLOR = (0, 0, 0)        # the game's chat backing is black
DEFAULT_TAB_OPACITY = 45     # percent; Settings.lua's Skin.ChatOpacity default
BACK_TAB_SHARE = 0.55        # a back tab's opacity, as a share of the open one's
RADIUS = 3                   # corners, as the rest of the skin

# The chat-style window's frame: size, and how far in from each outer edge
# its line runs (None: the piece has no such edge), as make_skin_art.swift
# measured them from the game's art.
FRAME_PIECES = [
    # name, w, h, top, bottom, left, right
    ("box_im_bottom", 103, 36, None, 0, None, None),
    ("box_im_bottom_left_noadorn", 36, 36, None, 0, 0, None),
    ("box_im_right_noadorn", 36, 36, None, None, None, 0),
    ("box_im_side_left", 36, 105, None, None, 0, None),
    ("box_im_side_right", 36, 237, None, None, None, 0),
    ("box_im_upper", 434, 37, 0, None, None, None),
    ("box_im_upper_left_noadorn", 36, 36, 0, None, 0, None),
    ("box_im_upper_right_noadorn", 36, 36, 0, None, None, 0),
]

TAB_TOP = 2
# name, w, the column of its left and right edges (None: none on this piece)
TAB_PIECES = [
    ("w", 204, 1, 202),
    ("n", None, None, None),     # 182 wide in front, 183 behind, as the game's
    ("e", 13, None, None),       # right edge: 10 in front, 11 behind
]

FAR = 100  # an edge a piece doesn't have runs this far off it


def rounded_inside(x, y, x0, y0, x1, y1, r):
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    r = max(0.0, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
    cx, cy = min(max(x, x0 + r), x1 - r), min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def coverage(px, py, box, r):
    """How much of pixel (px, py) the rounded box covers, 0-1."""
    corners = [(px, py), (px + 1, py), (px, py + 1), (px + 1, py + 1)]
    if all(rounded_inside(x, y, *box, r) for x, y in corners):
        return 1.0   # the shape is convex
    step = 1 / SAMPLES
    offsets = [(i + 0.5) * step for i in range(SAMPLES)]
    hits = sum(rounded_inside(px + ox, py + oy, *box, r) for oy in offsets for ox in offsets)
    return hits / (SAMPLES * SAMPLES)


def inset(box, d):
    x0, y0, x1, y1 = box
    return (x0 + d, y0 + d, x1 - d, y1 - d)


def over(top, bottom):
    """Straight-alpha `top` over `bottom`, both (r, g, b, a 0-1)."""
    a = top[3] + bottom[3] * (1 - top[3])
    if a <= 0:
        return (0, 0, 0, 0)
    return tuple((t * top[3] + b * bottom[3] * (1 - top[3])) / a for t, b in zip(top[:3], bottom[:3])) + (a,)


def outlined(w, h, outline, fill, line_alpha):
    """A filled rounded box with a 1-wide gold line just inside `outline`."""
    inner = inset(outline, 1)
    pixels = []
    for py in range(h):
        row = []
        for px in range(w):
            body = coverage(px, py, inner, RADIUS - 1)
            line = coverage(px, py, outline, RADIUS) - body
            row.append(over(GOLD + (line_alpha * line,), fill[:3] + (fill[3] * body,)))
        pixels.append(row)
    return pixels


def flat(w, h, fill):
    return [[fill] * w for _ in range(h)]


def write_tga(path, pixels):
    """32-bit TGA, uncompressed, top-left origin, straight alpha."""
    h, w = len(pixels), len(pixels[0])
    out = bytearray([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    out += struct.pack("<HH", w, h) + bytes([32, 0x28])
    for row in pixels:
        for r, g, b, a in row:
            alpha = round(255 * a)
            out += bytes([round(b), round(g), round(r), alpha]) if alpha > 0 else bytes(4)
    with open(path, "wb") as f:
        f.write(out)


def tab_pieces(opacity):
    """The six chat tab pieces, name -> pixels, with the open tab black at
    `opacity` percent - the chat window's - and the others dimmer."""
    pieces = {}
    for front in (True, False):
        side = "front" if front else "back"
        alpha = max(0, min(100, opacity)) / 100 * (1 if front else BACK_TAB_SHARE)
        line = FRONT_LINE if front else FAINT_LINE
        for piece, w, left, right in TAB_PIECES:
            if piece == "n":
                w = 182 if front else 183
            if piece == "e":
                right = 10 if front else 11
            # Open at the bottom, where the tab meets the window.
            outline = (-FAR if left is None else left, TAB_TOP,
                       w + FAR if right is None else right + 1, 28 + FAR)
            pieces[f"chat_tab_tier1_middle_{side}_{piece}"] = outlined(w, 28, outline, TAB_COLOR + (alpha,), line)
    return pieces


def main():
    art = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Art")
    written = {}

    written["chat_back"] = flat(32, 32, CHAT_FILL)
    written["box_im_center_silver"] = flat(128, 128, CHAT_FILL)
    for name, w, h, top, bottom, left, right in FRAME_PIECES:
        outline = (-FAR if left is None else left, -FAR if top is None else top,
                   w + FAR if right is None else w - right, h + FAR if bottom is None else h - bottom)
        written[name] = outlined(w, h, outline, CHAT_FILL, FAINT_LINE)
    written.update(tab_pieces(DEFAULT_TAB_OPACITY))

    for name, pixels in written.items():
        write_tga(os.path.join(art, f"frame_{name}.tga"), pixels)
    print(f"Wrote {len(written)} pieces to {os.path.normpath(art)}")


if __name__ == "__main__":
    main()
