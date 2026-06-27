//
//  AAMetrics.swift
//  AgentAtlas
//
//  Design tokens — spacing, sizing, density. Source: DESIGN_SYSTEM.md §5–6.
//

import Cocoa

enum AAMetrics {
    static let toolbarHeight: CGFloat = 46   // unified toolbar/titlebar + sidebar/detail header pad
    static let windowRadius: CGFloat = 13
    static let hairline: CGFloat = 0.5

    // Monogram tile sizes in use (§3)
    static let monoInline: CGFloat = 16
    static let monoRow: CGFloat = 19
    static let monoDetail: CGFloat = 26
}

/// Density tweak (§6). Drives row height, vertical padding, font size, row gap.
enum AADensity {
    case compact
    case comfortable

    var rowHeight: CGFloat { self == .compact ? 30 : 38 }
    var fontSize: CGFloat { self == .compact ? 12 : 12.5 }
    var padY: CGFloat { self == .compact ? 5 : 8 }
    var rowGap: CGFloat { self == .compact ? 1 : 2 }
}
