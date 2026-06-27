//
//  Agent.swift
//  AgentAtlas
//
//  Domain — an AI coding agent. Pure data (Sendable, scanner-safe).
//  Visual representation (monogram tile colors) lives in ModelAppearance.swift.
//  Source: UI/source/aa-data.jsx, DESIGN_SYSTEM.md §3.
//

import Foundation

nonisolated struct Agent: Identifiable, Hashable, Sendable {
    let key: String       // stable id, e.g. "claude"
    let name: String      // display, e.g. "Claude Code"
    let mono: String      // monogram glyph, e.g. "C" / "Cu"
    let hue: Double       // OKLCH hue for the tile
    let neutral: Bool     // generic / unknown → neutral gray tile

    var id: String { key }
}

nonisolated enum AgentCatalog {
    static let all: [Agent] = [
        Agent(key: "claude",   name: "Claude Code", mono: "C",  hue: 22,  neutral: false),
        Agent(key: "cursor",   name: "Cursor",      mono: "Cu", hue: 222, neutral: false),
        Agent(key: "windsurf", name: "Windsurf",    mono: "W",  hue: 196, neutral: false),
        Agent(key: "cline",    name: "Cline",       mono: "Cl", hue: 152, neutral: false),
        Agent(key: "codex",    name: "Codex",       mono: "Co", hue: 270, neutral: false),
        Agent(key: "gemini",   name: "Gemini",      mono: "G",  hue: 256, neutral: false),
        Agent(key: "continue", name: "Continue",    mono: "Cn", hue: 178, neutral: false),
        Agent(key: "qwen",     name: "Qwen",        mono: "Q",  hue: 312, neutral: false),
        Agent(key: "augment",  name: "Augment",     mono: "Au", hue: 38,  neutral: false),
        Agent(key: "generic",  name: "AGENTS.md",   mono: "A",  hue: 0,   neutral: true),
    ]

    private static let byKey: [String: Agent] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    static func agent(_ key: String) -> Agent {
        byKey[key] ?? Agent(key: key, name: key.capitalized, mono: "?", hue: 0, neutral: true)
    }

    /// Agents that currently have at least one artifact, in catalog order.
    static func present(in artifacts: [Artifact]) -> [Agent] {
        let keys = Set(artifacts.map(\.agentKey))
        return all.filter { keys.contains($0.key) }
    }
}
