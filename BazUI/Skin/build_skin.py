#!/usr/bin/env python3
"""Builds the BazUI skin: ui/skins/BazUI/SkinDefinition.xml.

The skin restyles the parts of the game's own interface a plugin can't
touch, in BazUI's look, and hides the ones BazUI's modules replace. Each part
is separate, so anyone can keep the game's own version of it:

Parts with a switch in BazUI's settings (Skin tab):
  Toolbar       the toolbar trimmed to its round menu buttons, top centre.
                Its frame, XP strip, store button, central ring, bag buttons
                and "^" main-menu arrow go (Escape still opens the main
                menu) - and with them the game's main quickslot bar, so this
                needs BazUI's Action bars module.
  Radar         a thin gold ring with a gold north point round the radar (all
                ten hope/dread variants), and small hope/dread gems.
  CastBar       the cast (induction) bar: a dark track with a gold outline.
  Buffs         buff and debuff icons: an even gold edge.
  QuestTracker  the quest tracker: a soft dark backing behind each quest,
                darker under the mouse, a gold accent on the selected one.
  Windows       the game's windows (and chat): BazUI's dark panel and thin
                gold line in place of the silver bevel and Celtic corners,
                a dark gold-edged title plaque, and text buttons without
                their blue glow.

Parts that follow a BazUI module - while it's on, the game's own is hidden:
  Action bars   the game's quickslot bars: the docked extra bars and the
                floating Ctrl/Alt/Shift/Extra bars (they keep firing on their
                keys; BazUI's bars are what you see and click).
  Menu          the menu buttons' art, in every state: the buttons still take
                the clicks and show their tooltips, BazUI's Menu module draws
                over them and fades the row in on hover. Their positions go
                to Menu/Geometry.lua for it. Module off: the game's art.
  Class bar     the Rune-keeper attunement display.

The switches are read from BazUI's saved settings, so: change them in game,
log out (or close the settings window - it saves), run this, then exit and
relaunch the game - it only reads skin files at start-up. --on/--off
override the saved switches; what was built goes to Skin/Built.lua, which
BazUI's Skin tab compares with the current settings.

Art names and sizes come from the U46.2 skinning pack (lunarwtr,
lotrointerface.com). BazUI's art is drawn by Skin/make_skin_art.swift into
Skin/Art, and copied into the skin folder here.

Sizes are in UI units, which the game multiplies by the Global UI scale (and
the Toolbar scale). Toolbar positions, measured on a real screen
(2026-10-12, 1920x1080 at 0.90), are in the game's own points, with the
toolbar drawn about 51 right of and 20 below its X and Y. So give the
resolution the game's Options show (under CrossOver's high-res mode the
game's 1920x1080 is in points, two real pixels each) and the Global scale;
left out, the last build's are used again:

    python3 build_skin.py 1920 1080 0.9
    python3 build_skin.py                      # same screen as last time
    python3 build_skin.py --off Radar,Buffs

The menu goes top centre, unless it has been dragged somewhere in BazUI
(layout mode, Ctrl+\\): that spot is read from BazUI's saved settings.
--centre ignores it. --toolbar-scale is the Toolbar slider in Options > UI
Settings; with the Menu module off it's the only way the buttons grow: a skin
box bigger than the button art just repeats the art.

Pick "BazUI" in Options > UI Settings > Current User Skin and Accept.
"""

import colorsys
import glob
import os
import re
import shutil
import sys

import make_chat_art

# Switches in the Skin tab, in its order: key, and what it does.
SKIN_PARTS = [
    ("Toolbar", "toolbar trimmed to the menu buttons, top centre"),
    ("Radar", "radar frame: gold ring, hope/dread gems"),
    ("CastBar", "cast bar: dark track, gold outline"),
    ("Buffs", "buff and debuff icons: gold edge"),
    ("QuestTracker", "quest tracker: dark backing, gold accent"),
    ("Windows", "game windows: dark panel, gold line"),
]
# BazUI modules whose game counterpart the skin hides while they're on.
MODULE_PARTS = [
    ("ActionBars", "game's quickslot bars hidden"),
    ("Menu", "game's menu art hidden, BazUI draws the menu"),
    ("ClassBar", "game's attunement display hidden"),
]

# Point measurements below were made on screen at Global UI scale 0.9 (a
# 1920x1080 game, 2026-10-12); they're scaled by the UI scale built for, so
# the menu keeps its size and place at any resolution and scale.
MEASURED_AT_SCALE = 0.9

# The toolbar draws this many points right of and below the X and Y its skin
# gives it (measured from screenshots), and it isn't the same everywhere: 51
# right and 20 below on a Mac under CrossOver (1920x1080 at 0.9); on Windows
# (3840x2160 at 2.0, 2026-10-12) the buttons came out 622 px left of BazUI's
# icons with the Mac's numbers, so 229 left. The script runs where the game
# does, so the platform picks. Only one screen was measured on each: if the
# menu doesn't open panels somewhere else, build with --show-menu-buttons and
# measure again.
TOOLBAR_NUDGE = {"darwin": (51, 20), "win32": (-229, 0)}
TOOLBAR_NUDGE_X, TOOLBAR_NUDGE_Y = TOOLBAR_NUDGE.get(sys.platform, TOOLBAR_NUDGE["darwin"])

# On Windows the toolbar's own Y doesn't bring it down from the top of the
# screen (told -31, -18 and 13: drawn at 0 each time), while its buttons'
# places inside it are kept - so there the buttons are moved down inside it.
# (Only the top-centre spot has been tried this way.)
TOOLBAR_TOP_PINNED = sys.platform == "win32"

# Hidden elements go off screen at 1x1, which the game draws as nothing.
HIDDEN = (-3000, -3000, 1, 1)

LEFT_SLOTS = 7       # ToolbarButton_Slot_1..7
RIGHT_SLOTS = 8      # ToolbarButton_RightSlot_1..8

# Menu buttons not to show. Right slots 3-8 are the six bags (BazUI's bag
# window replaces them); the main menu is the "^" arrow.
HIDDEN_BUTTONS = {"ToolBarButton_MainMenu"} | {f"ToolbarButton_RightSlot_{i}" for i in range(3, 9)}

# Game menu art: its own size (bigger and it tiles), in UI units.
GAME_BUTTON, GAME_GAP = 25, 6
# BazUI's menu: its icon size and spacing, in points on screen.
BAZUI_ICON, BAZUI_GAP = 26, 8

TOP_MARGIN = 6       # points between the top of the screen and the buttons
PIPS_W, PIPS_H = 100, 60   # class-resource display under the buttons
PIPS_GAP = 4

# Class-resource displays that live on the toolbar; one shows per class.
PIP_DISPLAYS = [
    "GamePlay_FervorPipDisplay", "GamePlay_AimPipDisplay", "GamePlay_MettlePipDisplay",
    "GamePlay_VenomPipDisplay", "GamePlay_RampagePipDisplay", "Gameplay_AtunementUI",
]

# Toolbar pieces the trimmed toolbar doesn't keep.
TOOLBAR_HIDDEN = [
    "ToolbarFieldMain",            # the frame and background
    "Toolbar_Quickslot",           # main quickslot bar (keys 1 to =)
    "Toolbar_Quickslot_Page",      # its page arrows
    "LevelMeter",                  # XP strip - BazUI's XP module draws its own
    "ToolbarFieldMain_LevelMeter_Left_Cap", "ToolbarFieldMain_LevelMeter_Mid_Left_Cap",
    "ToolbarFieldMain_LevelMeter_Mid_Right_Cap", "ToolbarFieldMain_LevelMeter_Right_Cap",
    "ViolentModeIndicator",        # the big central ring
    "AutoAttackIndicatorButton",
    "Toolbar_WebstoreButton",
    "ToolbarButton_CustomizeSlots",
]

# Art for the panels the customizable menu buttons can open, and the states
# it comes in: all made transparent while BazUI draws the menu.
MENU_BUTTON_ART = [
    "options", "skills", "trait_panel", "quest", "journal", "accomplishment_journal",
    "crafting", "fellowship", "fellowing", "fellowshipmaker", "raid", "kinship",
    "reputation", "mounts", "mountedcombat", "mailui", "hobby", "collection", "bio",
    "destiny", "destinypoints", "itemAdvancement_panel", "pvppanel", "housingpanelbutton",
    "help", "inventory", "webstore", "main_menu", "start_menu", "friends",
]
MENU_ART_STATES = ["normal", "rollover", "pressed", "highlight", "ghosted"]

# Game art -> BazUI art (Skin/Art/<name>.tga), per part.
RADAR_ART = {
    **{ring: "radar_ring" for ring in ["no_hope_no_dread", "hope_1", "hope_9", "hope_10", "hope_34",
                                       "hope_56", "hope_78", "dread_34", "dread_56", "dread_78"]},
    "no_hope_no_dread_gem": "radar_gem_neutral",
    **{f"gem_hope{i}": f"radar_gem_hope{i}" for i in range(1, 6)},
    **{f"gem_dread{i}": f"radar_gem_dread{i}" for i in range(1, 6)},
}
CAST_BAR_ART = {
    "progress_overlay_background_left": "cast_track_left",
    "progress_overlay_background_center": "cast_track_center",
    "progress_overlay_background_right": "cast_track_right",
    "progress_overlay_left": "cast_frame_left",
    "progress_overlay_center": "cast_frame_center",
    "progress_overlay_right": "cast_frame_right",
}
BUFF_ART = {"icon_effect_frame": "buff_frame"}
# The blue glow inside each end of a text button (TextButton_Highlight_l/_r,
# the store's "buy now" highlight on ~500 buttons; the game spells it
# "highight"): gone, leaving the button's dark fill and gold line.
BUTTON_GLOW_ART = {name: "invisible" for name in [
    "buynow_button_highight_l_small", "buynow_button_highight_small",   # 32x14, most buttons
    "buynow_button_highight_l", "buynow_button_highight",               # 68x58, the big ones
]}
TRACKER_ART = {
    # The strip behind each quest, in its four states - what today's tracker draws.
    **{f"questTrackerWindow_questEntry_{state}_{p}": f"trackerentry_{state}_{p}"
       for state in ("normal_normal", "normal_rollover", "highlight_normal", "highlight_rollover")
       for p in ("l", "c", "r")},
    # Its window frame and the older base, in case either still shows.
    **{f"questTrackerWindow_{p}": f"tracker_{p}" for p in ("tl", "t", "tr", "l", "c", "r", "bl", "b", "br")},
    **{f"TrackerBase_{game}": f"trackerbase_{p}" for game, p in [
        ("topLeft", "tl"), ("topCenter", "t"), ("topRight", "tr"),
        ("midLeft", "l"), ("midCenter", "c"), ("midRight", "r"),
        ("bottomLeft", "bl"), ("bottomCenter", "b"), ("bottomRight", "br")]},
}

# The floating quickslot bars: panel name, and the bar element inside it.
UNDOCKED_BARS = [
    ("CtrlBar", "CtrlBar"),
    ("AltBar", "AltBar"),
    ("ShiftBar", "ShiftBar"),
    ("ExtraShortcutBar1", "ExtraShortcutBar1"),
    ("ExtraShortcutBar2", "ExtraShortcutBar2"),
]

DRAG_BOX = ("HiddenDragBox_DragBox", "HiddenDragBox_DragBar", "HiddenDragBox_TitleText")


def element(element_id, x, y, w, h, indent, children=None):
    pad = "\t" * indent
    head = f'{pad}<Element ID="{element_id}" X="{x}" Y="{y}" Width="{w}" Height="{h}">'
    if not children:
        return [head + "</Element>"]
    return [head] + children + [f"{pad}</Element>"]


def hidden_panel(comment, panel_id, root, inner):
    """A floating panel squashed to 1x1 with `inner` (and its layout-mode
    drag box, so nothing shows in Ctrl+\\ either) off screen."""
    children = []
    for name in (*inner, *DRAG_BOX):
        children += element(name, *HIDDEN, 2)
    return ["", f"\t<!-- {comment} -->", f'\t<PanelFile ID="{panel_id}">',
            *element(root, 0, 0, 1, 1, 1, children), "\t</PanelFile>"]


def mappings(comment, art):
    return ["", f"\t<!-- {comment} -->"] + \
        [f'\t<Mapping ArtAssetID="{game}" FileName="{ours}.tga"></Mapping>' for game, ours in art.items()]


def window_art():
    """Skin/Art/frame_<name>.tga replaces the game art <name>: the window
    frames, backgrounds and title plaques make_skin_art.swift draws."""
    here = os.path.dirname(os.path.abspath(__file__))
    names = sorted(os.path.basename(path)[len("frame_"):-len(".tga")]
                   for path in glob.glob(os.path.join(here, "Art", "frame_*.tga")))
    return {name: "frame_" + name for name in names}


def write_flat_tga(path, rgba=(0, 0, 0, 0), size=32):
    """A 32-bit TGA of one colour (r, g, b, alpha 0-255): fully transparent by
    default, for art the skin wants gone."""
    r, g, b, a = rgba
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    size & 255, size >> 8, size & 255, size >> 8, 32, 0x28])
    with open(path, "wb") as f:
        f.write(header + bytes([b, g, r, a]) * (size * size))


# --show-menu-buttons: the game's menu buttons, normally invisible under
# BazUI's icons, as see-through magenta - to check they line up.
MENU_DEBUG = (255, 0, 255, 110)

# The hues the grey accent turns grey, in degrees: BazUI's golds (40-43) and
# its warm darks - not the radar gems' red dread (to 29) or green hope.
GOLD_HUES = (28, 58)


def grey_gold(path):
    """Turns the gold in a 32-bit TGA grey of the same brightness, for the
    grey accent (BazUI's own windows do the same with the Grayscale blend)."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    if data[2] != 2 or data[16] != 32:
        return
    for i in range(18 + data[0], len(data) - 3, 4):
        b, g, r = data[i], data[i + 1], data[i + 2]
        hi, lo = max(r, g, b), min(r, g, b)
        if hi == 0 or (hi - lo) / hi <= 0.1:
            continue
        hue = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)[0] * 360
        if GOLD_HUES[0] <= hue <= GOLD_HUES[1]:
            v = round(0.299 * r + 0.587 * g + 0.114 * b)
            data[i:i + 3] = bytes([v, v, v])
    with open(path, "wb") as f:
        f.write(data)


# MARK: - BazUI's saved settings

def parse_plugindata(text):
    """A PluginData file - `return { ["Key"] = value, ... }` - as a dict."""
    tokens = []
    for string, number, word, punct in re.findall(
            r'"((?:[^"\\]|\\.)*)"|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|([A-Za-z_]\w*)|([{}\[\]=,])', text):
        if punct:
            tokens.append(("p", punct))
        elif word:
            tokens.append(("w", word))
        elif number:
            tokens.append(("v", float(number)))
        else:
            tokens.append(("v", re.sub(r"\\(.)", r"\1", string)))
    pos = 0

    def value():
        nonlocal pos
        kind, token = tokens[pos]
        pos += 1
        if (kind, token) == ("p", "{"):
            table, index = {}, 1
            while tokens[pos] != ("p", "}"):
                if tokens[pos] == ("p", "["):
                    pos += 1
                    key = value()
                    pos += 2                          # "]" "="
                elif tokens[pos][0] == "w" and tokens[pos + 1] == ("p", "="):
                    key = tokens[pos][1]
                    pos += 2
                else:
                    key, index = index, index + 1
                table[key] = value()
                if tokens[pos] == ("p", ","):
                    pos += 1
            pos += 1
            return table
        if kind == "w":
            return {"true": True, "false": False, "nil": None}.get(token, token)
        return token

    if tokens and tokens[0] == ("w", "return"):
        pos = 1
    return value() if pos < len(tokens) else {}


def load_settings(lotro_docs):
    """BazUI's account settings - the most recently saved, if there are
    several accounts - or {} if there are none yet."""
    files = glob.glob(os.path.join(lotro_docs, "PluginData", "*", "AllServers", "BazUI_Settings.plugindata"))
    if not files:
        return {}
    path = max(files, key=os.path.getmtime)
    try:
        return parse_plugindata(open(path, encoding="utf-8", errors="replace").read())
    except (IndexError, ValueError) as e:
        print(f"Couldn't read {path} ({e}) - building with everything on")
        return {}


def setting(settings, *path, default=None):
    node = settings
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return default
        node = node[key]
    return node


def saved_menu_spot(settings):
    """Where the menu was dragged to in BazUI, as (left, top) in points, or None."""
    left, top = setting(settings, "Menu", "Left", default=-1), setting(settings, "Menu", "Top", default=-1)
    if not isinstance(left, float) or not isinstance(top, float) or left < 0 or top < 0:
        return None
    return round(left), round(top)


def last_build(out_dir):
    """The screen, scale and toolbar scale the skin was last built for, from
    its header, or None."""
    try:
        text = open(os.path.join(out_dir, "SkinDefinition.xml"), encoding="utf-8").read(2000)
    except OSError:
        return None
    m = re.search(r"for a (\d+)x(\d+) game at UI scale (\d+(?:\.\d+)?), Toolbar scale (\d+(?:\.\d+)?)", text)
    return (int(m.group(1)), int(m.group(2)), float(m.group(3)), float(m.group(4))) if m else None


# MARK: - The skin

def toolbar(screen_w, scale, toolbar_scale, bazui_menu, spot):
    """The trimmed toolbar's XML lines, and where its shown menu buttons land
    on screen as [(x, y, w, h)] in points. `spot` is the row's top-left in
    points, or None for top centre."""
    s = scale * toolbar_scale   # points per UI unit inside the toolbar
    k = scale / MEASURED_AT_SCALE   # the measured points, at this scale

    names = ["ToolBarButton_MainMenu"] + [f"ToolbarButton_Slot_{i}" for i in range(1, LEFT_SLOTS + 1)] \
        + [f"ToolbarButton_RightSlot_{i}" for i in range(1, RIGHT_SLOTS + 1)]
    shown = [name for name in names if name not in HIDDEN_BUTTONS]

    if bazui_menu:
        button = round(BAZUI_ICON * k / s)
        step = (BAZUI_ICON + BAZUI_GAP) * k / s
    else:
        button, step = GAME_BUTTON, GAME_BUTTON + GAME_GAP
    offsets = [round(n * step) for n in range(len(shown))]
    row_w = offsets[-1] + button

    # Allowing for where the game actually draws the toolbar.
    left, top = spot if spot else (round((screen_w - row_w * s) / 2), round(TOP_MARGIN * k))
    if TOOLBAR_TOP_PINNED:
        inner = round(top / s)            # the buttons' Y inside the toolbar, in UI units
        field_y, top = 0, round(inner * s)
    else:
        inner, field_y = 0, top - round(TOOLBAR_NUDGE_Y * k)
    on_screen = [(round(left + x * s), top, round(button * s), round(button * s)) for x in offsets]

    children = []
    for name, x in zip(shown, offsets):
        children += element(name, x, inner, button, button, 2)
    for name in names:
        if name in HIDDEN_BUTTONS:
            children += element(name, *HIDDEN, 2)
    pips_x = (row_w - PIPS_W) // 2
    for name in PIP_DISPLAYS:
        children += element(name, pips_x, inner + button + PIPS_GAP, PIPS_W, PIPS_H, 2)
    for name in TOOLBAR_HIDDEN:
        children += element(name, *HIDDEN, 2)

    lines = ["", "\t<!-- Toolbar: menu buttons only. -->", '\t<PanelFile ID="ID_UISkin_Toolbar">',
             *element("ToolbarField", left - round(TOOLBAR_NUDGE_X * k), field_y,
                      row_w, inner + button + PIPS_GAP + PIPS_H, 1, children),
             "\t</PanelFile>"]
    return lines, on_screen


def build(screen_w, screen_h, scale, toolbar_scale, parts, spot=None, show_buttons=False):
    """The skin XML, and the BazUI menu's buttons on screen (empty when the
    game draws its own menu). `parts` is every key in SKIN_PARTS and
    MODULE_PARTS -> on/off, already reconciled. `show_buttons` draws the
    game's menu buttons magenta instead of invisible."""
    bazui_menu = parts["Toolbar"] and parts["Menu"]
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<!--",
        "\tBazUI skin by Baz4k - built by Plugins/Baz4k/BazUI/Skin/build_skin.py",
        f"\tfor a {screen_w}x{screen_h} game at UI scale {scale}, Toolbar scale {toolbar_scale}.",
        "\tParts: " + ", ".join(f"{key} {'on' if on else 'off'}" for key, on in parts.items()) + ".",
        "\tRebuild with that script rather than editing this file.",
        "-->",
        "<opt>",
        '\t<SkinName Name="BazUI"></SkinName>',
    ]

    buttons = []
    if parts["Toolbar"]:
        toolbar_lines, on_screen = toolbar(screen_w, scale, toolbar_scale, bazui_menu, spot)
        lines += toolbar_lines
        if bazui_menu:
            buttons = on_screen

    if parts["ActionBars"]:
        lines += ["", "\t<!-- Extra quickslot bars docked on the toolbar. -->",
                  '\t<PanelFile ID="ID_UISkin_Toolbar_Quickslot_Extended_Scaler">',
                  *element("Toolbar_Quickslot_Extended_Scaler", 0, 0, 1, 1, 1,
                           element("Toolbar_Quickslot_Extended", *HIDDEN, 2)),
                  "\t</PanelFile>"]
        for panel, bar in UNDOCKED_BARS:
            root = f"GamePlay_Undocked_{panel}"
            lines += hidden_panel(f"Floating {bar}.", f"ID_UISkin_{root}", root, [bar])

    if parts["ClassBar"]:
        lines += hidden_panel("Rune-keeper attunement: BazUI's class bar shows it instead.",
                              "ID_UISkin_GamePlay_AtunementBar", "GamePlay_AtunementBar",
                              ["GamePlay_AtunementPipDisplay"])

    if parts["Radar"]:
        lines += mappings("The radar's frame and hope/dread gems.", RADAR_ART)
    if parts["CastBar"]:
        lines += mappings("The cast bar: dark track, gold outline.", CAST_BAR_ART)
    if parts["Buffs"]:
        lines += mappings("Buff and debuff icons: gold edge.", BUFF_ART)
    if parts["QuestTracker"]:
        lines += mappings("The quest tracker: dark backing per quest, gold accent.", TRACKER_ART)
    if parts["Windows"]:
        lines += mappings("The game's windows: dark panel, gold line, gold-edged title plaque.", window_art())
        lines += mappings("Text buttons: no blue glow at the ends.", BUTTON_GLOW_ART)

    if bazui_menu:
        art = "menu_debug" if show_buttons else "invisible"
        lines += mappings("Menu buttons invisible in every state: BazUI draws the menu.",
                          {f"{name}_{state}": art for name in MENU_BUTTON_ART for state in MENU_ART_STATES})

    lines += ["</opt>", ""]
    return "\n".join(lines), buttons


def write_geometry(path, screen_w, screen_h, buttons):
    rows = ",\n".join(f"\t\t{{ Left = {x}, Top = {y}, Width = {w}, Height = {h} }}" for x, y, w, h in buttons)
    lua = f"""-- Menu/Geometry.lua
-- Written by Skin/build_skin.py - don't edit. Where the BazUI skin puts the
-- game's (invisible) menu buttons, in game points on a {screen_w}x{screen_h}
-- screen, so the Menu module can draw its icons over them. None: the skin
-- leaves the game's menu as it is.

BazUI.MenuGeometry = {{
	ScreenWidth = {screen_w},
	ScreenHeight = {screen_h},
	Buttons = {{
{rows + "," if rows else ""}
	}},
}};
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(lua)


def write_built(path, wanted, chat_opacity, accent):
    """What the skin was built from - each switch and module as it was, the
    chat tabs' opacity and the accent - so BazUI's Skin tab can tell when the
    settings have moved on."""
    rows = "\n".join(f"\t{key} = {'true' if on else 'false'}," for key, on in wanted.items())
    rows += f"\n\tChatOpacity = {chat_opacity},"
    rows += f'\n\tAccent = "{accent}",'
    lua = f"""-- Skin/Built.lua
-- Written by Skin/build_skin.py - don't edit. The settings the BazUI skin
-- was last built from: the Skin tab's switches and the modules it follows.

BazUI.SkinBuilt = {{
{rows}
}};
"""
    with open(path, "w", encoding="utf-8") as f:
        f.write(lua)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Build the BazUI skin.")
    parser.add_argument("width", type=int, nargs="?", help="game resolution width (default: as last built)")
    parser.add_argument("height", type=int, nargs="?", help="game resolution height")
    parser.add_argument("scale", type=float, nargs="?", help="Global UI scale (Options > UI Settings)")
    parser.add_argument("--toolbar-scale", type=float, help="the Toolbar scale slider (default: as last built, or 1)")
    parser.add_argument("--centre", "--center", action="store_true",
                        help="put the menu top centre even if it was dragged elsewhere in BazUI")
    keys = [key for key, _ in SKIN_PARTS]
    parser.add_argument("--on", default="", help="skin parts to build regardless of the settings: " + ",".join(keys))
    parser.add_argument("--off", default="", help="skin parts to leave out regardless of the settings")
    parser.add_argument("--out", help="output folder (default: ui/skins/BazUI)")
    parser.add_argument("--chat-opacity", type=int,
                        help="chat tab opacity in percent, to match the game's chat window (default: the Skin tab's)")
    parser.add_argument("--show-menu-buttons", action="store_true",
                        help="draw the game's menu buttons see-through magenta, to check they sit under BazUI's icons")
    parser.add_argument("--accent", choices=["gold", "grey"], help="accent colour (default: the General tab's)")
    args = parser.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    lotro_docs = os.path.normpath(os.path.join(here, "..", "..", "..", ".."))
    out_dir = args.out or os.path.join(lotro_docs, "ui", "skins", "BazUI")

    last = last_build(out_dir)
    if args.scale is None:
        if last is None:
            parser.error("give the resolution and UI scale, e.g. 1920 1080 0.9 (there's no earlier build to reuse)")
        args.width, args.height, args.scale = last[:3]
        print(f"Screen as last built: {args.width}x{args.height} at UI scale {args.scale}")
    if args.toolbar_scale is None:
        args.toolbar_scale = last[3] if last else 1.0

    # The switches: saved settings (missing = on, as BazUI's defaults), then
    # the command line.
    settings = load_settings(lotro_docs)
    wanted = {key: setting(settings, "Skin", key, default=True) is not False for key, _ in SKIN_PARTS}
    wanted.update({key: setting(settings, "Core", "Modules", key, default=True) is not False
                   for key, _ in MODULE_PARTS})
    for names, on in ((args.on, True), (args.off, False)):
        for name in filter(None, (n.strip() for n in names.split(","))):
            if name not in wanted:
                parser.error(f"no skin part called {name} - they're {', '.join(keys)}")
            wanted[name] = on

    chat_opacity = args.chat_opacity
    if chat_opacity is None:
        chat_opacity = setting(settings, "Skin", "ChatOpacity", default=make_chat_art.DEFAULT_TAB_OPACITY)
    chat_opacity = max(0, min(100, round(float(chat_opacity))))
    accent = args.accent or ("grey" if setting(settings, "Core", "Accent") == "grey" else "gold")

    parts = dict(wanted)
    if parts["Toolbar"] and not parts["ActionBars"]:
        parts["Toolbar"] = False
        print("Toolbar left as the game's: trimming it hides the game's main quickslot bar, "
              "and the Action bars module is off")

    spot = None if args.centre else saved_menu_spot(settings)
    if spot and parts["Toolbar"]:
        print(f"Menu at {spot[0]},{spot[1]} (where it was dragged in BazUI; --centre to ignore)")
    xml, buttons = build(args.width, args.height, args.scale, args.toolbar_scale, parts, spot, args.show_menu_buttons)

    os.makedirs(out_dir, exist_ok=True)
    for art in glob.glob(os.path.join(here, "Art", "*.tga")):
        shutil.copy(art, out_dir)
    write_flat_tga(os.path.join(out_dir, "invisible.tga"))
    write_flat_tga(os.path.join(out_dir, "menu_debug.tga"), MENU_DEBUG)
    # The chat tabs, over the copies, at the chat window's opacity.
    for name, pixels in make_chat_art.tab_pieces(chat_opacity).items():
        make_chat_art.write_tga(os.path.join(out_dir, f"frame_{name}.tga"), pixels)
    if accent == "grey":
        for art in glob.glob(os.path.join(out_dir, "*.tga")):
            grey_gold(art)
    path = os.path.join(out_dir, "SkinDefinition.xml")
    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(xml)

    geometry = os.path.join(here, "..", "Menu", "Geometry.lua")
    write_geometry(geometry, args.width, args.height, buttons)
    write_built(os.path.join(here, "Built.lua"), wanted, chat_opacity, accent)

    print(f"Wrote {path}: {args.width}x{args.height} game, scale {args.scale}, toolbar {args.toolbar_scale}")
    for key, about in SKIN_PARTS + MODULE_PARTS:
        print(f"  {'on ' if parts[key] else 'off'}  {key:<13} {about}")
    print(f"  chat tabs at {chat_opacity}% opacity - match the chat window's own setting")
    print(f"  accent: {accent}")
    print(f"Wrote {os.path.normpath(geometry)}: {len(buttons)} BazUI menu buttons")
    print("Exit and relaunch the game to see it.")


if __name__ == "__main__":
    main()
