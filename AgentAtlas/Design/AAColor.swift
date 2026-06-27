//
//  AAColor.swift
//  AgentAtlas
//
//  Design tokens — color. Source: UI/design-system/DESIGN_SYSTEM.md §1.
//  Dark theme only for MVP. Accent-derived tints approximate `color-mix`
//  with alpha compositing (visually equivalent on the dark surfaces).
//

import Cocoa

enum AAColor {

    // MARK: Surfaces — cool neutral dark
    static let winBg     = srgb(0x1A, 0x1B, 0x1E) // window body
    static let s0        = srgb(0x14, 0x15, 0x17) // search fields, code/raw wells
    static let s0b       = srgb(0x19, 0x1A, 0x1D) // list & detail backgrounds
    static let s1        = srgb(0x21, 0x23, 0x27) // rows, cards, controls, banners
    static let s2        = srgb(0x2A, 0x2C, 0x31) // hover, tags, progress track
    static let border    = srgb(0x34, 0x36, 0x3B) // dividers / hairlines
    static let borderSoft = srgb(0x2A, 0x2C, 0x30) // inner separators

    // MARK: Text
    static let tx     = srgb(0xEC, 0xEC, 0xEE) // primary
    static let txDim  = srgb(0xA1, 0xA3, 0xA9) // secondary / descriptions
    static let txMute = srgb(0x6D, 0x6F, 0x76) // tertiary, paths, counts

    // MARK: Brand accent (gold) — the single source of truth for tints.
    // Live Tweak (Э5): changing it re-tints ac12/ac22/acTx everywhere on reload.
    static var accent = srgb(0xE8, 0xB4, 0x4C)

    static var ac12: NSColor { accent.withAlphaComponent(0.14) } // fills
    static var ac22: NSColor { accent.withAlphaComponent(0.24) } // selected bg / borders
    static var acTx: NSColor { lerp(accent, .white, 0.12) }      // text/icon on dark

    // Curated accent options for the Tweaks panel (Э5).
    static let accentOptions: [(name: String, color: NSColor)] = [
        ("gold",    srgb(0xE8, 0xB4, 0x4C)),
        ("teal",    srgb(0x34, 0xD1, 0xBF)),
        ("indigo",  srgb(0x7C, 0x8C, 0xF8)),
        ("green",   srgb(0x5B, 0xD1, 0x7A)),
        ("magenta", srgb(0xE8, 0x79, 0xB9)),
        ("coral",   srgb(0xE0, 0x6A, 0x52)),
    ]

    // MARK: Semantic — flags & health (kept distinct from the gold accent)
    static let good   = srgb(0x5B, 0xD1, 0x7A) // enabled
    static let warn   = srgb(0xEB, 0x8C, 0x3C) // conflict / override
    static let danger = srgb(0xE0, 0x6A, 0x52) // parse error / broken symlink
    static let info   = srgb(0x6B, 0xA6, 0xF0) // duplicate
    static let violet = srgb(0xB0, 0x8C, 0xF0) // symlink

    // MARK: Helpers

    static func srgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }

    /// Linear blend of two colors in sRGB. `t = 0` → a, `t = 1` → b.
    static func lerp(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let ca = a.usingColorSpace(.sRGB) ?? a
        let cb = b.usingColorSpace(.sRGB) ?? b
        return NSColor(srgbRed: ca.redComponent + (cb.redComponent - ca.redComponent) * t,
                       green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * t,
                       blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * t,
                       alpha: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * t)
    }

    /// OKLCH → sRGB NSColor (Björn Ottosson's conversion). Used for per-agent
    /// monogram hues so they match the design's `oklch(...)` swatches exactly.
    static func oklch(_ L: CGFloat, _ C: CGFloat, _ hueDeg: CGFloat, alpha: CGFloat = 1) -> NSColor {
        let h = hueDeg * .pi / 180
        let a = C * cos(h)
        let bb = C * sin(h)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * bb
        let m_ = L - 0.1055613458 * a - 0.0638541728 * bb
        let s_ = L - 0.0894841775 * a - 1.2914855480 * bb

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return NSColor(srgbRed: gammaEncode(r), green: gammaEncode(g), blue: gammaEncode(b), alpha: alpha)
    }

    private static func gammaEncode(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c >= 0.0031308 ? 1.055 * pow(c, 1 / 2.4) - 0.055 : 12.92 * c
    }
}
