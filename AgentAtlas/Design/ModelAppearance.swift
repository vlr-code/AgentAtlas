//
//  ModelAppearance.swift
//  AgentAtlas
//
//  Visual representation for domain types — kept out of the model so the
//  model stays nonisolated/Sendable for the background scanner. These live
//  on @MainActor because they vend NSColor. Source: DESIGN_SYSTEM.md §1, §3.
//

import Cocoa

@MainActor
extension Agent {
    /// Monogram tile colors (fill / border / glyph), matching the design swatches.
    var tile: (fill: NSColor, border: NSColor, glyph: NSColor) {
        if neutral {
            return (AAColor.srgb(0x96, 0x99, 0xA0, 0.22),
                    AAColor.srgb(0x96, 0x99, 0xA0, 0.50),
                    AAColor.srgb(0xC2, 0xC4, 0xCA))
        }
        let h = CGFloat(hue)
        return (AAColor.oklch(0.62, 0.14, h, alpha: 0.32),
                AAColor.oklch(0.72, 0.14, h, alpha: 0.66),
                AAColor.oklch(0.84, 0.15, h))
    }
}

@MainActor
extension Flag {
    /// Semantic color (§1) — kept distinct from the gold accent.
    var color: NSColor {
        switch self {
        case .disabled:   return AAColor.txMute
        case .conflict:   return AAColor.warn
        case .duplicate:  return AAColor.info
        case .symlink:    return AAColor.violet
        case .parseError: return AAColor.danger
        case .overrides:  return AAColor.warn
        }
    }
}
