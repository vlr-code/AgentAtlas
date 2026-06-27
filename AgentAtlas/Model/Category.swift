//
//  Category.swift
//  AgentAtlas
//
//  Domain — artifact category. Source: aa-data.jsx, DESIGN_SYSTEM.md §4.
//

import Foundation

nonisolated enum Category: String, CaseIterable, Identifiable, Hashable, Sendable {
    case rules
    case mcp
    case skills
    case commands
    case subagents
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rules:     return "Rules"
        case .mcp:       return "MCP Servers"
        case .skills:    return "Skills"
        case .commands:  return "Commands"
        case .subagents: return "Subagents"
        case .settings:  return "Settings / Hooks"
        }
    }

    /// Asset name in UI/design-system/icons/category/ (currentColor stroke icons).
    var iconName: String {
        switch self {
        case .rules:     return "rules"
        case .mcp:       return "mcp-servers"
        case .skills:    return "skills"
        case .commands:  return "commands"
        case .subagents: return "subagents"
        case .settings:  return "settings"
        }
    }
}
