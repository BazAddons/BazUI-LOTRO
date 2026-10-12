// make_skin_art.swift
// Draws the art the BazUI skin puts in place of the game's own, as 32-bit
// TGAs in Skin/Art (build_skin.py copies them into the skin folder).
//
// One look throughout - BazUI's: flat dark panels, one thin gold line, a
// soft shadow - so every skinned piece of the game matches BazUI's own
// windows. Each replacement is drawn at exactly the size of the art it
// replaces (a different size and the game repeats it), with its edges where
// the original's visible edges are, measured from the U46.2 skinning pack
// (lunarwtr, lotrointerface.com): change these numbers and the geometry
// changes; change the palette and everything follows.
//
//   swift make_skin_art.swift

import Foundation
import CoreGraphics

// MARK: - Palette (the same tokens BazUI's plugin windows use)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
let gold = rgb(176, 141, 72)
let goldBright = rgb(226, 196, 122)
let panel = rgb(10, 8, 6, 0.80)          // windows and frames
let panelLight = rgb(10, 8, 6, 0.55)     // things that sit over the world for long: the tracker
let track = rgb(33, 28, 23, 0.90)        // bar backgrounds
let shadow = rgb(0, 0, 0, 0.9)

// MARK: - Drawing

// A context with y growing downward, like the game's coordinates.
func canvas(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(h))
    c.scaleBy(x: 1, y: -1)
    return c
}

func fill(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: CGColor) {
    c.setFillColor(color)
    c.fill(CGRect(x: x, y: y, width: w, height: h))
}

// A crisp 1-pixel line along a run of pixels.
func hline(_ c: CGContext, _ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, _ color: CGColor = gold) {
    fill(c, x0, y, x1 - x0, 1, color)
}
func vline(_ c: CGContext, _ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ color: CGColor = gold) {
    fill(c, x, y0, 1, y1 - y0, color)
}

func circle(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

// 32-bit TGA, uncompressed, top-left origin, straight (not premultiplied) alpha.
func writeTGA(_ c: CGContext, to path: String) throws {
    let w = c.width, h = c.height
    let data = c.data!.assumingMemoryBound(to: UInt8.self)
    var out = Data([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    UInt8(w & 255), UInt8(w >> 8), UInt8(h & 255), UInt8(h >> 8), 32, 0x28])
    for i in 0..<(w * h) {
        let r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2], a = data[i * 4 + 3]
        func un(_ v: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, Int(v) * 255 / Int(a))) }
        out.append(contentsOf: [un(b), un(g), un(r), a])
    }
    try out.write(to: URL(fileURLWithPath: path))
}

var written: [String: CGContext] = [:]
func art(_ name: String, _ w: Int, _ h: Int, _ draw: (CGContext) -> Void) {
    let c = canvas(w, h)
    draw(c)
    written[name] = c
}

// MARK: - Radar: ring (238x238 round a 170x170 map at 34,33) and gems (22x22)

art("radar_ring", 238, 238) { c in
    let r: CGFloat = 85, cx: CGFloat = 34 + 85, cy: CGFloat = 33 + 85
    c.saveGState()
    c.setShadow(offset: .zero, blur: 4, color: shadow)
    c.setStrokeColor(gold)
    c.setLineWidth(3)
    c.strokeEllipse(in: CGRect(x: cx - r - 1.5, y: cy - r - 1.5, width: 2 * r + 3, height: 2 * r + 3))
    c.restoreGState()
    c.setStrokeColor(rgb(10, 8, 6, 0.85))
    c.setLineWidth(1.5)
    c.strokeEllipse(in: CGRect(x: cx - r + 0.75, y: cy - r + 0.75, width: 2 * r - 1.5, height: 2 * r - 1.5))
    c.setFillColor(goldBright)
    c.beginPath()
    c.move(to: CGPoint(x: cx, y: cy - r - 9))
    c.addLine(to: CGPoint(x: cx + 5, y: cy - r + 1))
    c.addLine(to: CGPoint(x: cx - 5, y: cy - r + 1))
    c.closePath()
    c.fillPath()
}

let gems: [(String, CGColor)] = [
    ("radar_gem_neutral", rgb(226, 196, 122)),
    ("radar_gem_hope1", rgb(150, 205, 140)), ("radar_gem_hope2", rgb(115, 190, 110)),
    ("radar_gem_hope3", rgb(80, 175, 85)), ("radar_gem_hope4", rgb(55, 155, 65)), ("radar_gem_hope5", rgb(35, 135, 50)),
    ("radar_gem_dread1", rgb(215, 140, 130)), ("radar_gem_dread2", rgb(205, 105, 95)),
    ("radar_gem_dread3", rgb(195, 75, 65)), ("radar_gem_dread4", rgb(170, 50, 45)), ("radar_gem_dread5", rgb(140, 30, 35)),
]
for (name, color) in gems {
    art(name, 22, 22) { c in
        c.saveGState()
        c.setShadow(offset: .zero, blur: 2, color: shadow)
        c.setFillColor(color)
        circle(c, 11, 11, 5)
        c.restoreGState()
        c.setStrokeColor(gold)
        c.setLineWidth(1.2)
        c.strokeEllipse(in: CGRect(x: 6, y: 6, width: 10, height: 10))
    }
}

// MARK: - Cast bar (the game's induction bar)
//
// The bar is 255 wide, its meter at x 12-246, y 6-19. Behind it three
// background pieces (left 24, centre 143 repeated, right 27 at x 231); over
// it three frame pieces (left 24, centre 60 repeated, right 21 at x 236).
// BazUI's: a dark track one pixel round the meter, and a gold line on that
// edge.
let meterTop: CGFloat = 5, meterBottom: CGFloat = 20   // one pixel outside the meter

art("cast_track_left", 24, 24) { c in fill(c, 11, meterTop, 13, meterBottom - meterTop, track) }
art("cast_track_center", 143, 24) { c in fill(c, 0, meterTop, 143, meterBottom - meterTop, track) }
art("cast_track_right", 27, 24) { c in fill(c, 0, meterTop, 16, meterBottom - meterTop, track) }   // meter ends at 246 = 231 + 15

art("cast_frame_left", 24, 24) { c in
    vline(c, 11, meterTop, meterBottom)
    hline(c, 11, 24, meterTop)
    hline(c, 11, 24, meterBottom - 1)
}
art("cast_frame_center", 60, 24) { c in
    hline(c, 0, 60, meterTop)
    hline(c, 0, 60, meterBottom - 1)
}
art("cast_frame_right", 21, 24) { c in     // starts at x 236: the meter's right edge is at 10
    hline(c, 0, 11, meterTop)
    hline(c, 0, 11, meterBottom - 1)
    vline(c, 10, meterTop, meterBottom)
}

// MARK: - Buffs and debuffs: the frame behind each icon
//
// The art is 34x36 but the slot 36x36 with the 32x32 icon at 2,2, so the
// game repeats columns 0-1 at 34-35. A 2-pixel gold edge in columns 0-1 is
// therefore an even 2-pixel edge on all four sides, round the icon.

art("buff_frame", 34, 36) { c in
    fill(c, 0, 0, 34, 36, rgb(10, 8, 6))
    fill(c, 0, 0, 2, 36, gold)
    fill(c, 0, 0, 34, 2, gold)
    fill(c, 0, 34, 34, 2, gold)
}

// MARK: - Quest tracker
//
// The tracker window is a 3x3 of pieces: corners 113/122 wide, 43 (top) and
// 51 (bottom) tall; the edges and centre repeat. Its panel's edges sit at
// x 10 (left pieces), x 108 (right pieces, of 122), y 5 (top pieces) and
// y 31 (bottom pieces). BazUI's: a lighter see-through panel - it sits over
// the world all the time - with the gold line round it.
let trackerEdge = (left: CGFloat(10), right: CGFloat(108), top: CGFloat(5), bottom: CGFloat(31))

func trackerPiece(_ name: String, _ w: Int, _ h: Int, left: Bool = false, right: Bool = false,
                  top: Bool = false, bottom: Bool = false) {
    art(name, w, h) { c in
        let x0 = left ? trackerEdge.left : 0
        let x1 = right ? trackerEdge.right + 1 : CGFloat(w)
        let y0 = top ? trackerEdge.top : 0
        let y1 = bottom ? trackerEdge.bottom + 1 : CGFloat(h)
        fill(c, x0, y0, x1 - x0, y1 - y0, panelLight)
        if left { vline(c, x0, y0, y1) }
        if right { vline(c, x1 - 1, y0, y1) }
        if top { hline(c, x0, x1, y0) }
        if bottom { hline(c, x0, x1, y1 - 1) }
    }
}
trackerPiece("tracker_tl", 113, 43, left: true, top: true)
trackerPiece("tracker_t", 74, 43, top: true)
trackerPiece("tracker_tr", 122, 43, right: true, top: true)
trackerPiece("tracker_l", 113, 95, left: true)
trackerPiece("tracker_c", 74, 95)
trackerPiece("tracker_r", 122, 95, right: true)
trackerPiece("tracker_bl", 113, 51, left: true, bottom: true)
trackerPiece("tracker_b", 74, 52, bottom: true)
trackerPiece("tracker_br", 122, 51, right: true, bottom: true)

// What the tracker actually draws today: a strip behind each quest - left
// cap 8, middle 227 (repeated), right cap 8, 23 tall - in four states: the
// quest as it is, under the mouse, selected, selected and under the mouse.
// A quest runs over several lines, so the game repeats the strip downward
// too: flat fills and a left accent only, nothing that would show a seam.
// BazUI's: a soft dark backing that keeps the text readable over bright
// ground, darker under the mouse, and a gold accent down the left of the
// selected quest.
let entryStates: [(name: String, back: CGFloat, accent: CGColor?)] = [
    ("normal_normal", 0.30, nil),
    ("normal_rollover", 0.55, gold),
    ("highlight_normal", 0.45, gold),
    ("highlight_rollover", 0.62, goldBright),
]
for state in entryStates {
    let back = rgb(10, 8, 6, state.back)
    art("trackerentry_\(state.name)_l", 8, 23) { c in
        fill(c, 0, 0, 8, 23, back)
        if let accent = state.accent { fill(c, 0, 0, 2, 23, accent) }
    }
    art("trackerentry_\(state.name)_c", 227, 23) { c in fill(c, 0, 0, 227, 23, back) }
    art("trackerentry_\(state.name)_r", 8, 23) { c in fill(c, 0, 0, 8, 23, back) }
}

// The newer tracker base: a small 3x3 (corners 45x14, edges 12 wide / 3
// tall), its visible edge one pixel in.
func basePiece(_ name: String, _ w: Int, _ h: Int, left: Bool = false, right: Bool = false,
               top: Bool = false, bottom: Bool = false) {
    art(name, w, h) { c in
        let x0: CGFloat = left ? 1 : 0, x1: CGFloat = right ? CGFloat(w) - 1 : CGFloat(w)
        let y0: CGFloat = top ? 1 : 0, y1: CGFloat = bottom ? CGFloat(h) - 1 : CGFloat(h)
        fill(c, x0, y0, x1 - x0, y1 - y0, panelLight)
        if left { vline(c, x0, y0, y1) }
        if right { vline(c, x1 - 1, y0, y1) }
        if top { hline(c, x0, x1, y0) }
        if bottom { hline(c, x0, x1, y1 - 1) }
    }
}
basePiece("trackerbase_tl", 45, 14, left: true, top: true)
basePiece("trackerbase_t", 12, 14, top: true)
basePiece("trackerbase_tr", 45, 14, right: true, top: true)
basePiece("trackerbase_l", 45, 3, left: true)
basePiece("trackerbase_c", 12, 3)
basePiece("trackerbase_r", 45, 3, right: true)
basePiece("trackerbase_bl", 45, 14, left: true, bottom: true)
basePiece("trackerbase_b", 12, 14, bottom: true)
basePiece("trackerbase_br", 45, 14, right: true, bottom: true)

// MARK: - Windows
//
// The game's windows are a 3x3 of frame pieces - silver bevel, Celtic knots
// at the corners - over a tiled background, with a blue title plaque on top.
// BazUI's: the same dark panel as everywhere else, one thin gold line where
// the bevel was (a soft shadow outside it), clean corners, and a dark plaque
// edged in gold. Written as frame_<game art name>.tga; build_skin.py maps
// each onto the game art it's named after.
//
// Each piece: its size, how far in from each outer edge the game's line
// starts (-1: the piece has no such edge), and how opaque its fill is. The
// chat-style window's box_im pieces are drawn by make_chat_art.py.
let framePieces: [(name: String, w: Int, h: Int, top: Int, bottom: Int, left: Int, right: Int, fill: Int)] = [
    ("box_gold_bottom_left_light", 36, 36, -1, 1, 1, -1, 203), ("box_gold_bottom_light", 103, 36, -1, 1, -1, -1, 203),
    ("box_gold_lower_right_light", 36, 36, -1, 1, -1, 1, 203), ("box_gold_side_left_light", 36, 105, -1, -1, 1, -1, 203),
    ("box_gold_side_right_light", 36, 237, -1, -1, -1, 1, 203), ("box_gold_upper_left_light", 36, 36, 1, -1, 1, -1, 203),
    ("box_gold_upper_light", 434, 37, 1, -1, -1, -1, 203), ("box_gold_upper_right_light", 36, 36, 1, -1, -1, 1, 203),
    ("box_silver_bottom", 103, 36, -1, 1, -1, -1, 234), ("box_silver_bottom_left", 36, 36, -1, 1, 1, -1, 234),
    ("box_silver_bottom_left_light", 36, 36, -1, 1, 1, -1, 203), ("box_silver_bottom_left_noadorn_min", 36, 36, -1, 2, 2, -1, 233),
    ("box_silver_bottom_light", 103, 36, -1, 1, -1, -1, 203), ("box_silver_bottom_min", 16, 36, -1, 2, -1, -1, 233),
    ("box_silver_lower_right", 36, 36, -1, 1, -1, 1, 234), ("box_silver_lower_right_light", 36, 36, -1, 1, -1, 1, 203),
    ("box_silver_lower_right_noadorn_min", 36, 36, -1, 2, -1, 2, 233), ("box_silver_side_left", 36, 105, -1, -1, 1, -1, 234),
    ("box_silver_side_left_light", 36, 105, -1, -1, 1, -1, 203), ("box_silver_side_left_min", 36, 16, -1, -1, 2, -1, 233),
    ("box_silver_side_right", 36, 237, -1, -1, -1, 1, 234), ("box_silver_side_right_light", 36, 237, -1, -1, -1, 1, 203),
    ("box_silver_side_right_min", 36, 16, -1, -1, -1, 2, 233), ("box_silver_upper", 434, 37, 1, -1, -1, -1, 234),
    ("box_silver_upper_left", 36, 36, 1, -1, 1, -1, 234), ("box_silver_upper_left_light", 36, 36, 1, -1, 1, -1, 203),
    ("box_silver_upper_left_noadorn_min", 36, 36, 2, -1, 2, -1, 233), ("box_silver_upper_light", 434, 37, 1, -1, -1, -1, 203),
    ("box_silver_upper_min", 16, 37, 2, -1, -1, -1, 233), ("box_silver_upper_right", 36, 36, 1, -1, -1, 1, 234),
    ("box_silver_upper_right_light", 36, 36, 1, -1, -1, 1, 203), ("box_silver_upper_right_noadorn_min", 36, 36, 2, -1, -1, 2, 233),
    ("silver_border_bottom_left", 36, 36, -1, 1, 1, -1, 234), ("silver_border_bottom_right", 36, 36, -1, 1, -1, 1, 234),
    ("silver_border_top_left", 36, 36, 1, -1, 1, -1, 234), ("silver_border_top_right", 36, 36, 1, -1, -1, 1, 234),
]
let cornerRadius: CGFloat = 3

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    let k = max(0, min(radius, r.width / 2, r.height / 2))
    return CGPath(roundedRect: r, cornerWidth: k, cornerHeight: k, transform: nil)
}

// Each piece is drawn as part of the whole window's outline: an edge the
// piece doesn't have runs far off it, so edges are straight and only true
// corners round.
for p in framePieces {
    art("frame_" + p.name, p.w, p.h) { c in
        let w = CGFloat(p.w), h = CGFloat(p.h)
        let x0 = p.left >= 0 ? CGFloat(p.left) : -100
        let y0 = p.top >= 0 ? CGFloat(p.top) : -100
        let x1 = p.right >= 0 ? w - CGFloat(p.right) : w + 100
        let y1 = p.bottom >= 0 ? h - CGFloat(p.bottom) : h + 100
        let outline = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)

        c.addPath(rounded(outline.insetBy(dx: 1, dy: 1), cornerRadius - 1))
        c.setFillColor(rgb(10, 8, 6, CGFloat(p.fill) / 255))
        c.fillPath()
        c.setLineWidth(1)
        c.addPath(rounded(outline.insetBy(dx: -0.5, dy: -0.5), cornerRadius + 0.5))
        c.setStrokeColor(rgb(0, 0, 0, 0.55))
        c.strokePath()
        c.addPath(rounded(outline.insetBy(dx: 0.5, dy: 0.5), cornerRadius - 0.5))
        c.setStrokeColor(gold)
        c.strokePath()
    }
}

// Backgrounds, tiled inside the frame. Flat and the frame's own colour - the
// newer windows' navy gradient included - so there's no seam where the
// background meets the frame, and no repeat line in a tall window.
func flatBackground(_ name: String, _ w: Int, _ h: Int, _ alpha: Int) {
    art("frame_" + name, w, h) { c in fill(c, 0, 0, CGFloat(w), CGFloat(h), rgb(10, 8, 6, CGFloat(alpha) / 255)) }
}
flatBackground("base_box_center_silver", 128, 128, 233)
flatBackground("base_box_center_silver_light", 128, 128, 203)
flatBackground("base_box_center_silver_new", 283, 382, 235)
flatBackground("base_box_center_silver_gradient", 283, 382, 192)
flatBackground("base_box_center_silver_gradient_light", 283, 382, 240)

// The title plaque: rows 13-35 of a 42-tall strip; the left cap's plaque
// starts at x 23 (leaves outside it), the right cap's ends at x 11. BazUI's:
// a dark plaque a shade lighter than the window, edged in gold, with a soft
// shadow under it.
let plaque = (top: CGFloat(13), bottom: CGFloat(36))
func titlePiece(_ name: String, _ w: Int, left: CGFloat?, right: CGFloat?) {
    art("frame_" + name, w, 42) { c in
        let x0 = left ?? -100, x1 = right ?? CGFloat(w) + 100
        for (i, a) in [0.45, 0.25, 0.10].enumerated() {
            fill(c, max(0, x0 + 1), plaque.bottom + CGFloat(i), min(CGFloat(w), x1 - 1) - max(0, x0 + 1), 1, rgb(0, 0, 0, a))
        }
        let outline = CGRect(x: x0, y: plaque.top, width: x1 - x0, height: plaque.bottom - plaque.top)
        c.addPath(rounded(outline.insetBy(dx: 1, dy: 1), cornerRadius - 1))
        c.setFillColor(rgb(20, 17, 12, 0.97))
        c.fillPath()
        c.addPath(rounded(outline.insetBy(dx: 0.5, dy: 0.5), cornerRadius - 0.5))
        c.setStrokeColor(gold)
        c.setLineWidth(1)
        c.strokePath()
    }
}
for suffix in ["", "_gold"] {
    titlePiece("base_box_titlebar_left" + suffix, 35, left: 23, right: nil)
    titlePiece("base_box_titlebar_top" + suffix, 139, left: nil, right: nil)
    titlePiece("base_box_titlebar_right" + suffix, 35, left: nil, right: 12)
}

// MARK: - Inside windows
//
// What windows hold, in the same language: dark warm fills, gold lines at
// two strengths (full for what's active, dimmer for structure), no blue, no
// silver, no knots. Also frame_<game art name>, so the Windows switch covers it.

let goldDim = rgb(176, 141, 72, 0.5)

// The character panel's backdrop, one per colour the game offers: dark, lit
// softly where your character stands, the name band at the top (rows 0-67)
// a shade lighter.
for colour in ["aqua", "blue", "green", "mp", "orange", "purple", "red", "violet", "yellow"] {
    art("frame_character_panel_bg_\(colour)", 443, 522) { c in
        fill(c, 0, 0, 443, 68, rgb(24, 20, 14))
        c.saveGState()
        c.clip(to: CGRect(x: 0, y: 68, width: 443, height: 454))
        let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [rgb(34, 28, 19), rgb(9, 7, 5)] as CFArray, locations: [0, 1])!
        c.drawRadialGradient(glow, startCenter: CGPoint(x: 221, y: 300), startRadius: 0,
                             endCenter: CGPoint(x: 221, y: 300), endRadius: 330, options: [.drawsAfterEndLocation])
        c.restoreGState()
    }
}

// The character panel's inner frame: a box (lines at x 10 and 686, y 10 and
// the bottom) with dividers under the name band (y 81), between equipment
// and stats (x 454) and, on some, above the store button (y 461).
func innerFrame(_ name: String, _ w: Int, _ h: Int, bottom: CGFloat, dividers: [(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)]) {
    art("frame_" + name, w, h) { c in
        let box = CGRect(x: 10, y: 10, width: 677, height: bottom + 1 - 10)
        c.setLineWidth(1)
        c.addPath(rounded(box.insetBy(dx: -0.5, dy: -0.5), cornerRadius + 0.5))
        c.setStrokeColor(rgb(0, 0, 0, 0.45))
        c.strokePath()
        c.addPath(rounded(box.insetBy(dx: 0.5, dy: 0.5), cornerRadius - 0.5))
        c.setStrokeColor(rgb(176, 141, 72, 0.7))
        c.strokePath()
        for d in dividers {
            fill(c, d.x0, d.y0, d.x1 - d.x0 + 1, d.y1 - d.y0 + 1, goldDim)
        }
    }
}
let nameRule = (x0: CGFloat(11), y0: CGFloat(81), x1: CGFloat(453), y1: CGFloat(81))
let statsRule = (x0: CGFloat(454), y0: CGFloat(11), x1: CGFloat(454), y1: CGFloat(534))
let storeRule = (x0: CGFloat(455), y0: CGFloat(461), x1: CGFloat(685), y1: CGFloat(461))
innerFrame("character_panel_equipment_border", 697, 546, bottom: 535, dividers: [nameRule, statsRule, storeRule])
innerFrame("character_panel_appearance_border", 697, 546, bottom: 535, dividers: [nameRule, statsRule, storeRule])
innerFrame("character_panel_sessionplayer_equipment_border", 697, 546, bottom: 535, dividers: [nameRule, statsRule])
innerFrame("character_panel_equipment_border_MP", 701, 545, bottom: 534,
           dividers: [nameRule, (x0: 454, y0: 20, x1: 454, y1: 533)])

// The character panel's tabs (Equipment, Cosmetic Outfits): rounded top
// from x 4 to 151, sides down to the panel's top line at y 24. The open
// tab is bright and open at the bottom, joining the panel; the others dim,
// with the panel's line running under them.
for active in [true, false] {
    art("frame_character_panel_tab_border_" + (active ? "active" : "inactive"), 157, 27) { c in
        if active {
            c.move(to: CGPoint(x: 4.5, y: 24))
            c.addArc(tangent1End: CGPoint(x: 4.5, y: 2.5), tangent2End: CGPoint(x: 151.5, y: 2.5), radius: 6)
            c.addArc(tangent1End: CGPoint(x: 151.5, y: 2.5), tangent2End: CGPoint(x: 151.5, y: 24), radius: 6)
            c.addLine(to: CGPoint(x: 151.5, y: 24))
            c.closePath()
            c.setFillColor(rgb(176, 141, 72, 0.12))
            c.fillPath()
        }
        c.move(to: CGPoint(x: 4.5, y: 24))
        c.addArc(tangent1End: CGPoint(x: 4.5, y: 2.5), tangent2End: CGPoint(x: 151.5, y: 2.5), radius: 6)
        c.addArc(tangent1End: CGPoint(x: 151.5, y: 2.5), tangent2End: CGPoint(x: 151.5, y: 24), radius: 6)
        c.addLine(to: CGPoint(x: 151.5, y: 24))
        c.setStrokeColor(active ? gold : goldDim)
        c.setLineWidth(1)
        c.strokePath()
        if active {
            hline(c, 0, 5, 24)
            hline(c, 151, 157, 24)
        } else {
            hline(c, 0, 157, 24, rgb(176, 141, 72, 0.7))
        }
    }
}

// The store button under the stats (210x52): BazUI's button - dark fill,
// gold edge - lighter under the mouse, darker pressed.
for (suffix, back, edge) in [("normal", rgb(24, 20, 14), gold), ("highlight", rgb(36, 29, 20), goldBright),
                             ("pressed", rgb(14, 11, 8), gold)] {
    for mp in ["", "_mp"] {
        art("frame_character_panel_mtx_menu_button_\(suffix)\(mp)", 210, 52) { c in
            let r = CGRect(x: 1, y: 1, width: 208, height: 50)
            c.addPath(rounded(r, 5))
            c.setFillColor(back)
            c.fillPath()
            c.addPath(rounded(r.insetBy(dx: 0.5, dy: 0.5), 4.5))
            c.setStrokeColor(edge)
            c.setLineWidth(1)
            c.strokePath()
        }
    }
}

// Section headers in lists (Basic Stats, Offence...): a 9x16 strip the game
// repeats across. A dark bar with a gold rule under it.
for variant in ["darkblue", "MP"] {
    art("frame_box_treelist_header_\(variant)", 9, 16) { c in
        let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                               colors: [rgb(40, 33, 23), rgb(24, 20, 14)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(shade, start: .zero, end: CGPoint(x: 0, y: 15), options: [])
        hline(c, 0, 9, 15, rgb(176, 141, 72, 0.75))
    }
}

// Small square buttons: a dark box with a gold edge and a glyph - the
// window's close X, the +/- that open and close list sections, checkboxes.
enum Glyph { case cross, minus, plus, check, none }
func smallButton(_ name: String, _ size: Int, _ glyph: Glyph, hover: Bool = false, pressed: Bool = false,
                 ghosted: Bool = false) {
    art("frame_" + name, size, size) { c in
        let s = CGFloat(size)
        let r = CGRect(x: 0.5, y: 0.5, width: s - 1, height: s - 1)
        c.addPath(rounded(r, 2))
        c.setFillColor(pressed ? rgb(10, 8, 6) : hover ? rgb(36, 29, 20) : rgb(22, 18, 13))
        c.fillPath()
        c.addPath(rounded(r, 2))
        c.setStrokeColor(ghosted ? rgb(120, 110, 95, 0.6) : hover ? goldBright : gold)
        c.setLineWidth(1)
        c.strokePath()
        let ink = ghosted ? rgb(120, 110, 95, 0.7) : hover ? rgb(255, 238, 190) : goldBright
        let m = s / 2, k = max(2, (s - 6) / 2)
        c.setStrokeColor(ink)
        c.setLineWidth(s >= 16 ? 1.6 : 1.2)
        c.setLineCap(.round)
        switch glyph {
        case .cross:
            c.move(to: CGPoint(x: m - k + 1, y: m - k + 1)); c.addLine(to: CGPoint(x: m + k - 1, y: m + k - 1))
            c.move(to: CGPoint(x: m + k - 1, y: m - k + 1)); c.addLine(to: CGPoint(x: m - k + 1, y: m + k - 1))
        case .minus:
            c.move(to: CGPoint(x: m - k, y: m)); c.addLine(to: CGPoint(x: m + k, y: m))
        case .plus:
            c.move(to: CGPoint(x: m - k, y: m)); c.addLine(to: CGPoint(x: m + k, y: m))
            c.move(to: CGPoint(x: m, y: m - k)); c.addLine(to: CGPoint(x: m, y: m + k))
        case .check:
            c.move(to: CGPoint(x: m - k, y: m)); c.addLine(to: CGPoint(x: m - k / 3, y: m + k * 0.7))
            c.addLine(to: CGPoint(x: m + k, y: m - k * 0.8))
        case .none:
            break
        }
        c.strokePath()
    }
}
for mp in ["", "_mp"] {
    smallButton("titlebar_X_2" + mp, 16, .cross)
    smallButton("titlebar_X_2_mouseover" + mp, 16, .cross, hover: true)
    smallButton("titlebar_X_2_pressed" + mp, 16, .cross, pressed: true)
}
for new in ["", "_new"] {
    smallButton("collapse_button" + new, 16, .minus)
    smallButton("expand_button" + new, 16, .plus)
}
smallButton("new_collapse_normal", 19, .minus)
smallButton("new_collapse_pressed", 19, .minus, pressed: true)
smallButton("new_expand_normal", 19, .plus)
smallButton("new_expand_highlight", 19, .plus, hover: true)
smallButton("new_expand_pressed", 19, .plus, pressed: true)
smallButton("checkbox_02", 16, .check)
smallButton("checkbox_02_empty", 16, .none)
smallButton("checkbox_01", 10, .check)
smallButton("checkbox_01_empty", 10, .none)
smallButton("checkbox_01_ghosted", 10, .check, ghosted: true)
smallButton("checkbox_01_empty_ghosted", 10, .none, ghosted: true)

// MARK: - Controls in every window: text buttons, tabs, scrollbars
//
// Geometry measured from the game's art (sizes from the image files, which
// the pack's list doesn't always agree with).

// A vertical shade, lighter at the top.
func shade(_ c: CGContext, _ r: CGRect, _ top: CGColor, _ bottom: CGColor) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [top, bottom] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: r.minY), end: CGPoint(x: 0, y: r.maxY), options: [])
}
func lighter(_ color: CGColor, _ amount: CGFloat) -> CGColor {
    let k = color.components!
    return CGColor(srgbRed: min(1, k[0] + amount), green: min(1, k[1] + amount), blue: min(1, k[2] + amount), alpha: k[3])
}

// Text buttons, 20 tall: edges at rows 1 and 18, a shadow at row 19. The
// "left" piece is a whole button (edges at x 1 and 144, shadow to 146), the
// "mid" piece repeats, the "right" piece ends one (edge at x 17).
struct ButtonLook { let fill: CGColor; let edge: CGColor }
func buttonLook(_ state: String) -> ButtonLook {
    let selected = state.contains("highlighted") || state.hasSuffix("_gold")
    let hover = state.contains("mouseover"), pressed = state.contains("pressed")
    if state.contains("ghosted") { return ButtonLook(fill: rgb(22, 20, 17, 0.85), edge: rgb(110, 100, 85)) }
    if selected {
        return ButtonLook(fill: pressed ? rgb(44, 34, 17) : hover ? rgb(74, 58, 29) : rgb(58, 45, 22), edge: goldBright)
    }
    return ButtonLook(fill: pressed ? rgb(13, 11, 8) : hover ? rgb(40, 32, 22) : rgb(26, 21, 15), edge: hover ? goldBright : gold)
}
let buttonStates = ["normal", "mouseover", "pressed", "ghosted", "highlighted_normal", "highlighted_mouseover",
                    "highlighted_pressed", "normal_gold", "mouseover_gold", "pressed_gold", "highlighted_normal_gold",
                    "highlighted_mouseover_gold", "highlighted_pressed_gold"]
for prefix in ["textbutton", "mp_textbutton"] {
    for state in buttonStates {
        if prefix == "mp_textbutton" && (state.hasSuffix("_gold")) { continue }
        let look = buttonLook(state)
        for (piece, w, x0, x1) in [("left", 147, CGFloat(1), CGFloat(145)), ("mid", 120, CGFloat(-100), CGFloat(220)),
                                   ("right", 20, CGFloat(-100), CGFloat(18))] {
            art("frame_\(prefix)_\(piece)_\(state)", w, 20) { c in
                let outline = CGRect(x: x0, y: 1, width: x1 - x0, height: 18)
                // Shadow below and to the right, as the game's has.
                fill(c, max(0, x0 + 1), 19, min(CGFloat(w), x1 + 1) - max(0, x0 + 1), 1, rgb(0, 0, 0, 0.55))
                if x1 < CGFloat(w) {
                    fill(c, x1, 2, 1, 18, rgb(0, 0, 0, 0.55))
                    if x1 + 1 < CGFloat(w) { fill(c, x1 + 1, 3, 1, 17, rgb(0, 0, 0, 0.2)) }
                }
                c.saveGState()
                c.addPath(rounded(outline.insetBy(dx: 1, dy: 1), 1.5))
                c.clip()
                shade(c, outline, lighter(look.fill, 0.035), look.fill)
                c.restoreGState()
                c.addPath(rounded(outline.insetBy(dx: 0.5, dy: 0.5), 2))
                c.setStrokeColor(look.edge)
                c.setLineWidth(1)
                c.strokePath()
            }
        }
    }
}

// Tabs: the open one ("front") lit with a gold edge over its top and sides,
// the others ("back") dark and dim; both open at the bottom, where they meet
// the panel. Full size: rows 3 to 24/25, the "w" piece a whole tab (x 2 to
// 201), "n" repeating, "e" ending one (x 15). Small: rows 1 to 16/17, "w"
// x 1 to 144, "e" ending at x 11.
func tabPath(_ c: CGContext, _ x0: CGFloat, _ x1: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
    c.move(to: CGPoint(x: x0, y: bottom))
    c.addArc(tangent1End: CGPoint(x: x0, y: top), tangent2End: CGPoint(x: x1, y: top), radius: 3)
    c.addArc(tangent1End: CGPoint(x: x1, y: top), tangent2End: CGPoint(x: x1, y: bottom), radius: 3)
    c.addLine(to: CGPoint(x: x1, y: bottom))
}
func tab(_ name: String, _ w: Int, _ h: Int, top: CGFloat, bottom: CGFloat, left: CGFloat?, right: CGFloat?,
         front: Bool) {
    art("frame_" + name, w, h) { c in
        let x0 = left ?? -100, x1 = right.map { $0 + 1 } ?? CGFloat(w) + 100
        let fillTop = front ? rgb(46, 37, 25) : rgb(22, 18, 13, 0.95)
        let fillBottom = front ? rgb(28, 23, 16) : rgb(16, 13, 10, 0.95)
        c.saveGState()
        tabPath(c, x0 + 1, x1 - 1, top + 1, bottom + 1)
        c.closePath()
        c.clip()
        shade(c, CGRect(x: 0, y: top, width: CGFloat(w), height: bottom - top + 1), fillTop, fillBottom)
        c.restoreGState()
        tabPath(c, x0 + 0.5, x1 - 0.5, top + 0.5, bottom + 1)
        c.setStrokeColor(front ? gold : goldDim)
        c.setLineWidth(1)
        c.strokePath()
    }
}
for front in [true, false] {
    let side = front ? "front" : "back"
    let full = (top: CGFloat(3), bottom: CGFloat(front ? 25 : 24))
    tab("tab_tier1_middle_\(side)_w", 204, 28, top: full.top, bottom: full.bottom, left: 2, right: 201, front: front)
    tab("tab_tier1_middle_\(side)_n", front ? 182 : 183, 28, top: full.top, bottom: full.bottom, left: nil, right: nil, front: front)
    tab("tab_tier1_middle_\(side)_e", 18, 28, top: full.top, bottom: full.bottom, left: nil, right: 15, front: front)
    let small = (top: CGFloat(1), bottom: CGFloat(17))
    tab("tab_tier1_middle_\(side)_w_sm", 146, 20, top: small.top, bottom: small.bottom, left: 1, right: 144, front: front)
    tab("tab_tier1_middle_\(side)_n_sm", front ? 130 : 131, 20, top: small.top, bottom: small.bottom, left: nil, right: nil, front: front)
    tab("tab_tier1_middle_\(side)_e_sm", 13, 20, top: small.top, bottom: small.bottom - 1, left: nil, right: 11, front: front)
}
// The chat window's tabs are drawn by make_chat_art.py.

// Scrollbars, 10 wide: a dark track and a gold thumb (rounded at its ends),
// gold arrows; brighter under the mouse. The "10H" pieces are the
// horizontal ones - the same, turned on their side.
let thumbGold = rgb(150, 118, 60), thumbGoldHover = rgb(200, 164, 94)
art("frame_Base_ScrollBar", 10, 115) { c in
    fill(c, 0, 0, 10, 115, rgb(12, 10, 8, 0.9))
    fill(c, 4, 0, 2, 115, rgb(40, 33, 23, 0.9))
}
for hover in [false, true] {
    let suffix = hover ? "_mouseover" : ""
    let body = hover ? thumbGoldHover : thumbGold
    for horizontal in [false, true] {
        let kind = horizontal ? "10H" : "10"
        // Drawn upright; the horizontal ones are turned a quarter.
        func upright(_ name: String, _ draw: @escaping (CGContext) -> Void) {
            art("frame_scrollbar_\(kind)_\(name)\(suffix)", 10, 10) { c in
                if horizontal {
                    c.translateBy(x: 0, y: 10)
                    c.rotate(by: -.pi / 2)
                }
                draw(c)
            }
        }
        upright("thumb_top") { c in
            c.addPath(rounded(CGRect(x: 2, y: 1, width: 6, height: 12), 3)); c.setFillColor(body); c.fillPath()
            fill(c, 2, 3, 1, 7, lighter(body, 0.15))
        }
        upright("thumb_mid") { c in
            fill(c, 2, 0, 6, 10, body); fill(c, 2, 0, 1, 10, lighter(body, 0.15))
        }
        upright("thumb_bottom") { c in
            c.addPath(rounded(CGRect(x: 2, y: -3, width: 6, height: 12), 3)); c.setFillColor(body); c.fillPath()
            fill(c, 2, 0, 1, 7, lighter(body, 0.15))
        }
        upright("uparrow") { c in
            c.setFillColor(hover ? goldBright : gold)
            c.move(to: CGPoint(x: 5, y: 2)); c.addLine(to: CGPoint(x: 8.5, y: 7.5)); c.addLine(to: CGPoint(x: 1.5, y: 7.5))
            c.closePath(); c.fillPath()
        }
        upright("downarrow") { c in
            c.setFillColor(hover ? goldBright : gold)
            c.move(to: CGPoint(x: 5, y: 8)); c.addLine(to: CGPoint(x: 8.5, y: 2.5)); c.addLine(to: CGPoint(x: 1.5, y: 2.5))
            c.closePath(); c.fillPath()
        }
    }
}

// MARK: - Write

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let outDir = here + "/Art"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, c) in written.sorted(by: { $0.key < $1.key }) {
    try writeTGA(c, to: "\(outDir)/\(name).tga")
}
print("Wrote \(written.count) pieces of skin art to \(outDir)")
