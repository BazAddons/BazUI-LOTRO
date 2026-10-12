// make_icons.swift
// Draws BazUI's art and writes it as 32-bit TGA files the game can load:
//   Menu/Icons/<name>.tga and <name>_hover.tga   the menu icons
//   ActionBars/Art/frame.tga                     the action-button frame
// (the skin's art - radar, cast bar, tracker... - is Skin/make_skin_art.swift)
// plus, optionally, a preview sheet.
//
// Every icon is the same disc - dark centre, thin gold ring - with a gold
// glyph drawn from simple vector shapes, so the set reads as one family.
//
//   swift make_icons.swift [preview.png]

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 64                      // pixels; drawn at half size in game for crisp 2x screens
let S = CGFloat(size)
let center = CGPoint(x: S / 2, y: S / 2)

struct Style {
    var ring: CGColor
    var ringWidth: CGFloat
    var glyph: CGColor
    var glow: CGFloat
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let normal = Style(ring: rgb(176, 141, 72), ringWidth: 2, glyph: rgb(226, 196, 122), glow: 0)
let hover = Style(ring: rgb(244, 214, 138), ringWidth: 2.5, glyph: rgb(255, 240, 200), glow: 6)
let backdropInner = rgb(46, 38, 28)
let backdropOuter = rgb(10, 8, 6)
let cutout = rgb(18, 15, 11)      // for holes and fold lines inside glyphs

// MARK: - Drawing helpers (y grows downward; the context is flipped)

func poly(_ c: CGContext, _ pts: [(CGFloat, CGFloat)]) {
    c.beginPath()
    c.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for p in pts.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
    c.closePath()
    c.fillPath()
}

func circle(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

func line(_ c: CGContext, _ pts: [(CGFloat, CGFloat)], width: CGFloat, color: CGColor) {
    c.saveGState()
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.beginPath()
    c.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for p in pts.dropFirst() { c.addLine(to: CGPoint(x: p.0, y: p.1)) }
    c.strokePath()
    c.restoreGState()
}

// Points along a circle, angles in degrees with y down (0 = right, 90 = down).
func arc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, from a0: CGFloat, to a1: CGFloat, steps: Int = 32) -> [(CGFloat, CGFloat)] {
    (0...steps).map { i in
        let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)) * .pi / 180
        return (x + r * cos(a), y + r * sin(a))
    }
}

// A head-and-shoulders figure.
func person(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat) {
    circle(c, x, y, 7 * s)
    c.beginPath()
    c.move(to: CGPoint(x: x - 15 * s, y: y + 25 * s))
    c.addLine(to: CGPoint(x: x - 15 * s, y: y + 20 * s))
    c.addCurve(to: CGPoint(x: x, y: y + 10 * s),
               control1: CGPoint(x: x - 15 * s, y: y + 13 * s), control2: CGPoint(x: x - 8 * s, y: y + 10 * s))
    c.addCurve(to: CGPoint(x: x + 15 * s, y: y + 20 * s),
               control1: CGPoint(x: x + 8 * s, y: y + 10 * s), control2: CGPoint(x: x + 15 * s, y: y + 13 * s))
    c.addLine(to: CGPoint(x: x + 15 * s, y: y + 25 * s))
    c.closePath()
    c.fillPath()
}

// MARK: - Glyphs, on a 64x64 grid

let glyphs: [String: (CGContext, Style) -> Void] = [
    "character": { c, _ in person(c, 32, 22, 1.05) },

    "skills": { c, _ in   // a lightning bolt
        poly(c, [(36, 12), (21, 35), (30.5, 35), (26, 52), (43, 28), (33.5, 28), (39, 12)])
    },

    "traits": { c, _ in   // a five-pointed star
        let pts = (0..<10).map { i -> (CGFloat, CGFloat) in
            let r: CGFloat = i % 2 == 0 ? 16 : 6.8
            let a = (CGFloat(i) * 36 - 90) * .pi / 180
            return (32 + r * cos(a), 33 + r * sin(a))
        }
        poly(c, pts)
    },

    "quests": { c, _ in   // an open book
        poly(c, [(14, 21), (30, 25), (30, 47), (14, 43)])
        poly(c, [(50, 21), (34, 25), (34, 47), (50, 43)])
    },

    "deeds": { c, _ in    // a medal on a ribbon
        poly(c, [(26, 31), (21, 50), (27, 46.5), (31.5, 51.5), (31.5, 34)])
        poly(c, [(38, 31), (43, 50), (37, 46.5), (32.5, 51.5), (32.5, 34)])
        circle(c, 32, 25, 10.5)
        c.setFillColor(cutout)
        circle(c, 32, 25, 5)
    },

    "crafting": { c, _ in // a hammer
        c.saveGState()
        c.translateBy(x: 32, y: 33)
        c.rotate(by: -.pi / 4)
        c.fill(CGRect(x: -2.6, y: -6, width: 5.2, height: 25))
        c.fill(CGRect(x: -11, y: -15, width: 22, height: 10))
        c.restoreGState()
    },

    "social": { c, s in   // two people
        person(c, 39, 21, 0.78)
        c.setFillColor(cutout)
        circle(c, 27, 27, 9.5)
        c.fill(CGRect(x: 12, y: 36, width: 30, height: 14))
        c.setFillColor(s.glyph)
        person(c, 27, 27, 0.9)
    },

    "fellowship": { c, s in // three people
        person(c, 20, 25, 0.62)
        person(c, 44, 25, 0.62)
        c.setFillColor(cutout)
        circle(c, 32, 26, 8.6)
        c.fill(CGRect(x: 18, y: 34, width: 28, height: 16))
        c.setFillColor(s.glyph)
        person(c, 32, 26, 0.85)
    },

    "map": { c, _ in      // a folded map
        poly(c, [(13, 20), (25, 16), (39, 21), (51, 17), (51, 44), (39, 48), (25, 43), (13, 47)])
        line(c, [(25, 17), (25, 42)], width: 1.6, color: cutout)
        line(c, [(39, 22), (39, 47)], width: 1.6, color: cutout)
    },

    "help": { c, s in     // a question mark
        line(c, arc(32, 25, 8.5, from: 180, to: 400) + [(32, 36), (32, 39)], width: 5.5, color: s.glyph)
        circle(c, 32, 47.5, 3.4)
    },

    "options": { c, _ in  // a gear
        var pts: [(CGFloat, CGFloat)] = []
        for i in 0..<8 {
            let base = CGFloat(i) * 45
            for (da, r) in [(-14.0, 12.5), (-8.0, 17.0), (8.0, 17.0), (14.0, 12.5)] as [(CGFloat, CGFloat)] {
                let a = (base + da) * .pi / 180
                pts.append((32 + r * cos(a), 32 + r * sin(a)))
            }
        }
        poly(c, pts)
        c.setFillColor(cutout)
        circle(c, 32, 32, 5.5)
    },

    "mail": { c, _ in     // an envelope
        c.fill(CGRect(x: 14, y: 20, width: 36, height: 25))
        line(c, [(15.5, 21.5), (32, 34), (48.5, 21.5)], width: 2.2, color: cutout)
    },

    "housing": { c, _ in  // a house
        poly(c, [(32, 13), (51, 30), (45.5, 30), (45.5, 49), (18.5, 49), (18.5, 30), (13, 30)])
        c.setFillColor(cutout)
        c.fill(CGRect(x: 28, y: 37, width: 8, height: 12))
    },

    "reputation": { c, _ in // a shield
        c.beginPath()
        c.move(to: CGPoint(x: 19, y: 15))
        c.addLine(to: CGPoint(x: 45, y: 15))
        c.addLine(to: CGPoint(x: 45, y: 31))
        c.addCurve(to: CGPoint(x: 32, y: 51), control1: CGPoint(x: 45, y: 41), control2: CGPoint(x: 38, y: 47))
        c.addCurve(to: CGPoint(x: 19, y: 31), control1: CGPoint(x: 26, y: 47), control2: CGPoint(x: 19, y: 41))
        c.closePath()
        c.fillPath()
    },

    "mounts": { c, s in   // a horseshoe
        line(c, arc(32, 31, 12.5, from: 135, to: 405), width: 7, color: s.glyph)
    },

    "collections": { c, _ in // a tunic
        poly(c, [(24, 14), (40, 14), (51, 22), (46, 31), (42, 28), (42, 50), (22, 50), (22, 28), (18, 31), (13, 22)])
    },

    "instances": { c, _ in // a castle gate
        poly(c, [(15, 50), (15, 18), (21, 18), (21, 23), (26, 23), (26, 18), (38, 18), (38, 23), (43, 23), (43, 18), (49, 18), (49, 50)])
        c.setFillColor(cutout)
        c.beginPath()
        c.move(to: CGPoint(x: 25, y: 50))
        c.addLine(to: CGPoint(x: 25, y: 38))
        c.addArc(center: CGPoint(x: 32, y: 38), radius: 7, startAngle: .pi, endAngle: 0, clockwise: false)
        c.addLine(to: CGPoint(x: 39, y: 50))
        c.closePath()
        c.fillPath()
    },
]

// MARK: - Rendering

func render(_ name: String, _ style: Style) -> CGContext {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: S)
    c.scaleBy(x: 1, y: -1)
    c.setShouldAntialias(true)

    // Disc: dark radial fill and a thin ring, with a soft glow on hover.
    let r: CGFloat = S / 2 - 3
    c.saveGState()
    if style.glow > 0 {
        c.setShadow(offset: .zero, blur: style.glow, color: style.ring)
    }
    c.setFillColor(backdropOuter)
    circle(c, center.x, center.y, r)
    c.restoreGState()

    c.saveGState()
    c.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    c.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [backdropInner, backdropOuter] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(gradient, startCenter: CGPoint(x: center.x, y: center.y - 6), startRadius: 0,
                         endCenter: center, endRadius: r, options: [])
    c.restoreGState()

    c.setStrokeColor(style.ring)
    c.setLineWidth(style.ringWidth)
    c.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))

    c.setFillColor(style.glyph)
    glyphs[name]!(c, style)
    return c
}

// The action-button frame: the menu's gold ring as a rounded square, drawn
// at twice the 38-unit slot so it stays sharp. The middle is see-through -
// it sits on top of the button - and the ring stays in the margin around the
// 32-unit icon, with a dark line inside it so it reads against bright icons.
let framePx = 76

func renderFrame() -> CGContext {
    let c = CGContext(data: nil, width: framePx, height: framePx, bitsPerComponent: 8, bytesPerRow: framePx * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(framePx))
    c.scaleBy(x: 1, y: -1)
    let full = CGRect(x: 0, y: 0, width: framePx, height: framePx)

    func rounded(_ inset: CGFloat) -> CGPath {
        let r = full.insetBy(dx: inset, dy: inset)
        return CGPath(roundedRect: r, cornerWidth: 9, cornerHeight: 9, transform: nil)
    }

    c.saveGState()
    c.setShadow(offset: .zero, blur: 2.5, color: rgb(0, 0, 0, 0.9))
    c.addPath(rounded(3))
    c.setStrokeColor(normal.ring)
    c.setLineWidth(3)
    c.strokePath()
    c.restoreGState()

    c.addPath(rounded(5.5))
    c.setStrokeColor(rgb(10, 8, 6, 0.85))
    c.setLineWidth(1.5)
    c.strokePath()
    return c
}

// 32-bit TGA, uncompressed, top-left origin, straight (not premultiplied) alpha.
func writeTGA(_ c: CGContext, to path: String) throws {
    let size = c.width
    let data = c.data!.assumingMemoryBound(to: UInt8.self)
    var out = Data([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    UInt8(size & 255), UInt8(size >> 8), UInt8(size & 255), UInt8(size >> 8), 32, 0x28])
    for i in 0..<(size * size) {
        let r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2], a = data[i * 4 + 3]
        func un(_ v: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, Int(v) * 255 / Int(a))) }
        out.append(contentsOf: [un(b), un(g), un(r), a])
    }
    try out.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let iconDir = here + "/Icons"
try FileManager.default.createDirectory(atPath: iconDir, withIntermediateDirectories: true)

let names = glyphs.keys.sorted()
var rendered: [(String, CGContext, CGContext)] = []
for name in names {
    let n = render(name, normal), h = render(name, hover)
    try writeTGA(n, to: "\(iconDir)/\(name).tga")
    try writeTGA(h, to: "\(iconDir)/\(name)_hover.tga")
    rendered.append((name, n, h))
}
print("Wrote \(names.count * 2) icons to \(iconDir)")

let artDir = here + "/../ActionBars/Art"
try FileManager.default.createDirectory(atPath: artDir, withIntermediateDirectories: true)
let frame = renderFrame()
try writeTGA(frame, to: "\(artDir)/frame.tga")
print("Wrote the action-button frame to \(artDir)/frame.tga")

// Optional preview: each icon, normal over hover, on a sky-ish backdrop at 2x.
if CommandLine.arguments.count > 1 {
    let cell = size * 2 + 8
    let w = cell * rendered.count + 8, h = cell * 2 + 8
    let sheet = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.setFillColor(rgb(150, 160, 175))
    sheet.fill(CGRect(x: 0, y: 0, width: w, height: h))
    sheet.interpolationQuality = .high
    for (i, (_, n, hv)) in rendered.enumerated() {
        let x = CGFloat(8 + i * cell)
        sheet.draw(n.makeImage()!, in: CGRect(x: x, y: CGFloat(cell + 8), width: CGFloat(size * 2), height: CGFloat(size * 2)))
        sheet.draw(hv.makeImage()!, in: CGRect(x: x, y: 8, width: CGFloat(size * 2), height: CGFloat(size * 2)))
    }
    let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, sheet.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("Preview: \(CommandLine.arguments[1]) - \(rendered.map { $0.0 }.joined(separator: ", "))")
}

// Optional frame preview: the frame over three stand-in icons and an empty
// slot, at 2x, written next to the icon preview as <name>-frame.png.
if CommandLine.arguments.count > 1 {
    let fw = framePx * 4 + 40, fh = framePx + 20
    let sheet = CGContext(data: nil, width: fw, height: fh, bitsPerComponent: 8, bytesPerRow: fw * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.setFillColor(rgb(150, 160, 175))
    sheet.fill(CGRect(x: 0, y: 0, width: fw, height: fh))
    let standIns = [rgb(200, 60, 90), rgb(70, 120, 200), rgb(220, 170, 60)]
    for i in 0..<4 {
        let x = CGFloat(10 + i * (framePx + 6)), y = CGFloat(10)
        if i < standIns.count {   // a 64-pixel "icon" in the middle, like the game's 32-unit icon at 2x
            sheet.setFillColor(standIns[i])
            sheet.fill(CGRect(x: x + 6, y: y + 6, width: 64, height: 64))
        }
        sheet.draw(frame.makeImage()!, in: CGRect(x: x, y: y, width: CGFloat(framePx), height: CGFloat(framePx)))
    }
    let path = CommandLine.arguments[1].replacingOccurrences(of: ".png", with: "-frame.png")
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, sheet.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("Frame preview: \(path)")
}
