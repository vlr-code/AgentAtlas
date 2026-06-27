//
//  AATypography.swift
//  AgentAtlas
//
//  Design tokens — type. Source: DESIGN_SYSTEM.md §2.
//  System fonts only. Sans for chrome/prose, mono for paths/config/code.
//  `bump` nudges the whole scale up uniformly (user preference).
//

import Cocoa

enum AAFont {

    /// Uniform size offset applied to every token (one source of truth).
    static let bump: CGFloat = 1

    // Rough scale (px) from §2, plus bump.
    static func display() -> NSFont { .systemFont(ofSize: 23 + bump, weight: .semibold) }
    static func displaySmall() -> NSFont { .systemFont(ofSize: 20 + bump, weight: .semibold) }
    static func title() -> NSFont { .systemFont(ofSize: 14.5 + bump, weight: .semibold) }
    static func titleSmall() -> NSFont { .systemFont(ofSize: 13.5 + bump, weight: .medium) }
    static func body(_ size: CGFloat = 12.5) -> NSFont { .systemFont(ofSize: size + bump, weight: .regular) }
    static func bodyMedium(_ size: CGFloat = 12.5) -> NSFont { .systemFont(ofSize: size + bump, weight: .medium) }
    static func secondary() -> NSFont { .systemFont(ofSize: 11.5 + bump, weight: .regular) }
    static func caption() -> NSFont { .systemFont(ofSize: 11 + bump, weight: .regular) }

    /// 10.5 uppercase section labels (700, 0.04em tracking) — §2.
    static func sectionLabel() -> NSFont { .systemFont(ofSize: 10.5 + bump, weight: .bold) }

    /// Monospaced: file paths, config/artifact names, code/raw bodies, env values.
    static func mono(_ size: CGFloat = 12, weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedSystemFont(ofSize: size + bump, weight: weight)
    }
}
