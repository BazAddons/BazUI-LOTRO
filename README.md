# BazUI for LOTRO

One plugin for your whole interface, by Baz4k — the Lord of the Rings Online
counterpart of BazUI for WoW. Each part is a module you can switch off in
`/bazui` › General, which hands that part back to the game.

BazUI has two halves:

- **The plugin** (`Plugins/Baz4k/BazUI`) — everything BazUI draws: bags,
  action bars, the menu, the XP bar, the settings window.
- **The skin** (`ui/skins/BazUI`) — the game's own interface, restyled to
  match: it hides the parts BazUI replaces, shrinks the toolbar to just its
  menu buttons, and redraws the radar frame, cast bar, buff icons, quest
  tracker and the game's windows in BazUI's dark-and-gold. Plugins can't move, hide or restyle most
  of the game's interface; skins can.

## Install

1. **Get it.** Download this repository (*Code › Download ZIP*), unzip it,
   rename the folder to **`Baz4k`** and put it in
   `Documents/The Lord of the Rings Online/Plugins/`, so you end up with
   `Plugins/Baz4k/BazUI.plugin` and `Plugins/Baz4k/BazUI/`. Or clone it there:
   `git clone https://github.com/BazAddons/BazUI-LOTRO.git Baz4k`.
2. **Load it** from the Plugin Manager (`/plugins manager`) and tick
   *Load on startup*.
3. **The skin:** build it for your screen (below), then Options › UI
   Settings › Current User Skin › **BazUI** › Accept, and **exit and
   relaunch** the game — it only reads skin files at start-up. The plugin
   works without it; the skin is what hides and restyles the game's own
   pieces.

### Building the skin

Skin positions are fixed numbers, so the skin is generated for your setup.
With [Python 3](https://www.python.org/) installed, from
`Documents/The Lord of the Rings Online`:

```
python3 Plugins/Baz4k/BazUI/Skin/build_skin.py 1920 1080 0.9
```

(On Windows, `py` instead of `python3`.)

Give the resolution your game's Options show and your Global UI scale (left
out, the last build's are used again). Under CrossOver's high-res mode that
resolution is in points (two real pixels each). `--toolbar-scale` matches
the game's Toolbar scale slider.

Each part of the skin can be switched off, keeping the game's own look for
it: tick or untick it in `/bazui` › **Skin**, then rebuild. The tab says
when the skin no longer matches the settings.

| Part | | Switched by |
|---|---|---|
| Toolbar | just the menu buttons, top centre | Skin tab (needs Action bars) |
| Radar | thin gold ring, hope/dread gems | Skin tab |
| Cast bar | dark track, gold outline | Skin tab |
| Buffs | gold-edged buff and debuff icons | Skin tab |
| Quest tracker | dark backing per quest, gold accent when selected | Skin tab |
| Windows | dark panel, thin gold line, gold-edged title plaque (chat too) | Skin tab |
| Game quickslot bars | hidden | Action bars module |
| Game menu art | hidden; BazUI draws the menu | Menu module |
| Game attunement display | hidden | Class bar module |

`--on` / `--off Radar,Buffs` override the saved switches for one build. The
builder also writes `Menu/Geometry.lua` (where the menu is) and
`Skin/Built.lua` (what it was built from) for the plugin.

## Modules

**Bags** — every bag in one window, opened by your bag keys.
- Grouped by category and sorted (best quality, then name, then stack size),
  or in the game's own bag order — right-click the background to switch.
- Click a heading to fold it. Search box at the top: name, category or
  quality ("rare", "crafting", "potion").
- Pin an item to a category by dropping it on that heading; *Categorize mode*
  (right-click menu) shows empty categories too. Pins are listed in the
  Bags settings tab.
- Rarity border, free-slot count in the title, your coin underneath.

**Action bars** — action buttons with no chrome. Six bars stand in for the
game's bars slot for slot (Main = keys 1–=, Ctrl, Alt, Shift, Extra 1 and 2);
plugins can't be bound to keys, so a key fires the game's (hidden) slot: give
a BazUI slot the same skill as the game slot with its key. The slot flashes
when its key is pressed. **New bar** in the settings tab makes more, clicked
only, as many as you like. Every bar has its own columns, rows and size (as a
% of the UI scale), and moves in layout mode. Drag a skill between slots to
move it; Shift+right-click empties a slot. Bars are locked by default: they
take no drops unless Shift is held, so nothing moves by accident. Optional gold button frames match
the menu.

**Menu** — BazUI's own icons over the game's (invisible) menu buttons, along
the top of the screen. The row fades in when the cursor comes near. The
game's buttons still take the clicks and show the tooltips; pick each slot's
icon in the Menu settings tab to match what it opens.

**Unit frames** — your frame and your target's: name, level, morale and
power with their numbers (current/max, percent or both), temporary morale
as a gold strip. The game's own vitals and target displays are switched off
while it's on. Click a frame to target, right-click for the game's menu.

**Class bar** — your class's resource. So far the Rune-keeper: attunement
as red battle pips left of a gold centre mark and green healing pips right
of it, the mark glowing while charged. By default it floats just above your
unit frame with no panel; it can stand on its own instead.

**XP bar** — a slim bar along the bottom; hover it for the numbers. Plugins
can't read XP, so it reads the running total from "You've earned … XP"
messages and remembers it per character.

## Moving things

The game's layout mode (**Ctrl+\\**) unlocks BazUI's bars too: they light up
and can be dragged. An alignment grid with gold centre lines appears with it
(`/bazui grid` shows it any time).

The menu is placed by the skin, so in layout mode it shows a **Menu** box
instead: drag that where you want the menu, then rebuild the skin (the
builder reads the saved spot; `--centre` puts it back) and relaunch.

## Commands

| | |
|---|---|
| `/bazui` | open or close the settings |
| `/bazui bags` | show or hide the bags (`/bazui bags view` switches layout) |
| `/bazui xp` | your level and XP in chat |
| `/bazui grid` | alignment grid on or off |
| `/bazui scale` | the UI scale numbers BazUI sees |
| `/bazui debug` | log what the game reports, for troubleshooting |
| `/bazui dump` | write the game's API names to the log, for development |

## Development

- **Log:** `PluginData/<account>/AllServers/BazUI_Log.plugindata` — loads,
  unloads, errors, and (with `/bazui debug`) module traces. Read it instead
  of copying chat.
- **API:** `/bazui dump` lists what the live client actually has; the
  official docs are the SSG U49 Lua documentation. Patch notes have been
  wrong (e.g. the scaling enum is `Turbine.UI.Lotro.UIScalingGroupType`).
- **Art:** `swift Menu/make_icons.swift [preview.png]` redraws the menu
  icons (`Menu/Icons`, 64-pixel TGAs, normal and `_hover`) and the
  action-button frame (`ActionBars/Art/frame.tga`) from vector shapes.
  `swift Skin/make_skin_art.swift` redraws the skin's art (`Skin/Art`), one
  palette for all of it; each piece is the exact size of the game art it
  replaces (measured from the U46.2 skinning pack), or the game tiles it.
- **Version:** `BazUI.Version` in `Main.lua` and `<Version>` in
  `BazUI.plugin`, bumped by one per release, not per change.
- Other plugins and skins are reference only: same techniques are fine,
  copied code isn't. Game data (e.g. `XP/Levels.lua`) comes from the LOTRO
  Wiki.
