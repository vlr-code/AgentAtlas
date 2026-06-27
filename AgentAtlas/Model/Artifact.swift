//
//  Artifact.swift
//  AgentAtlas
//
//  Domain — one config unit (a rule file, MCP server, skill, command,
//  subagent, or settings entry). Pure data (Sendable, scanner-safe).
//  Visual representation (flag colors) lives in ModelAppearance.swift.
//  Source: aa-data.jsx.
//

import Foundation

nonisolated enum FileFormat: String, Sendable {
    case md, json, yaml, toml

    var tag: String { rawValue.uppercased() }

    static func from(path: String) -> FileFormat {
        switch (path as NSString).pathExtension.lowercased() {
        case "json":        return .json
        case "yaml", "yml": return .yaml
        case "toml":        return .toml
        default:            return .md   // .md, .mdc, .clinerules, .cursorrules, dotfiles
        }
    }
}

/// Health/state flags. `enabled` is the absence of `.disabled`.
nonisolated enum Flag: String, Hashable, Sendable {
    case disabled
    case conflict
    case duplicate
    case symlink
    case parseError
    case overrides

    var label: String {
        switch self {
        case .disabled:   return "disabled"
        case .conflict:   return "conflict"
        case .duplicate:  return "duplicate"
        case .symlink:    return "symlink"
        case .parseError: return "parse error"
        case .overrides:  return "overrides"
        }
    }

    /// Asset name in UI/design-system/icons/flags/.
    var iconName: String {
        switch self {
        case .disabled:   return "flag-disabled"
        case .conflict:   return "flag-conflict"
        case .duplicate:  return "flag-duplicate"
        case .symlink:    return "flag-symlink"
        case .parseError: return "flag-parse-error"
        case .overrides:  return "flag-conflict"
        }
    }
}

nonisolated struct Artifact: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let agentKey: String
    let category: Category
    let scope: Scope
    let path: String          // display path, may be ~-abbreviated
    let realPath: String      // absolute path on disk
    let format: FileFormat
    var flags: Set<Flag> = []

    // Optional detail
    var symlinkTo: String? = nil
    var overrides: String? = nil      // what this artifact overrides (text)
    var broken: Bool = false          // dangling symlink / unreadable

    var agent: Agent { AgentCatalog.agent(agentKey) }
    var isEnabled: Bool { !flags.contains(.disabled) }

    /// The typeface signals "prose rule vs. machine config" (§2):
    /// a Markdown name renders sans; a config-file or dotfile name renders mono.
    var nameIsMono: Bool {
        if format != .md { return true }
        return name.hasPrefix(".")
    }

    /// A real problem (something broken), not an intentional override or a
    /// duplicate you may have on purpose. Drives the "Issues" tally/filter.
    var isIssue: Bool {
        broken || flags.contains(.parseError)
    }
}
