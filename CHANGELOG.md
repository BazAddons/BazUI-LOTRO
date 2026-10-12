## 007

**BazUI for LOTRO, on GitHub.** The first public version: the plugin, a
module per part, and a skin that brings the game's own interface into the
same dark-and-gold look. Every part can be switched off.

### Plugin

- **Bags** — every bag in one window: grouped by category and sorted, or in
  the game's bag order; search; fold a heading; pin an item to a category by
  dropping it on the heading; rarity borders, free slots and your coin.
- **Action bars** — no chrome, just the skills, key labels and a flash when
  the key fires. Six bars stand in for the game's (Main, Ctrl, Alt, Shift,
  Extra 1 and 2); **New bar** makes click-only bars, as many as you like.
  Every bar has its own columns, rows and size. Drag a skill between slots to
  move it; bars are locked unless Shift is held. Optional gold frames.
- **Menu** — BazUI's icons over the game's menu buttons, along the top of the
  screen, fading in when the cursor comes near.
- **Unit frames** — yours and your target's: name, level, morale and power
  with numbers, temporary morale.
- **Class bar** — Rune-keeper attunement as pips, docked above your frame.
- **XP bar** — a slim bar with the numbers on it when you hover; it reads XP
  from the game's messages, since plugins can't ask for it.
- **Settings** (`/bazui`) — a General tab to switch modules off, a Skin tab,
  and a tab per module. Layout mode (Ctrl+\\) moves everything, with an
  alignment grid.

### Skin

Built for your screen by `Skin/build_skin.py`; each part has a switch in the
Skin tab.

- **Toolbar** trimmed to its menu buttons; the game's quickslot bars, XP
  strip and attunement display hidden where BazUI replaces them.
- **Radar** with a thin gold ring and hope/dread gems; **cast bar**, **buff
  icons** and **quest tracker** restyled.
- **Windows** — frames, title plaques, tabs, buttons, scrollbars, checkboxes,
  section headers and the character panel in BazUI's look: no silver, no
  knots, no blue.

### Earlier (001–006, before GitHub)

One combined bag that follows your UI scale (001); bag fixes and scaling
(002–004); categories, sorting and the right-click menu (005); your coin in
the bag (006).
