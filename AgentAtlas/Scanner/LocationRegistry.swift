//
//  LocationRegistry.swift
//  AgentAtlas
//
//  Where each agent keeps its config — the map the scanner walks.
//  Global paths are relative to home; project paths to a project root.
//  Derived from UI/source/aa-data.jsx + the agents' documented locations.
//

import Foundation

/// How to turn a matched path into artifacts.
nonisolated enum Extraction: Sendable {
    case singleFile                 // the file itself is one artifact (rules / settings)
    case mcpServersJSON             // JSON file → one artifact per `mcpServers` entry
    case markdownGlob               // a dir of *.md files → one artifact each (commands / subagents)
    case skillFolders               // dir/*/SKILL.md → one artifact per skill folder
    case mdcGlob                    // a dir of *.mdc files (Cursor project rules)
}

nonisolated struct GlobalRule: Sendable {
    let agentKey: String
    let category: Category
    let relPath: String             // relative to home
    let format: FileFormat
    let extraction: Extraction
}

nonisolated struct ProjectRule: Sendable {
    let agentKey: String
    let category: Category
    let relPath: String             // relative to project root
    let format: FileFormat
    let extraction: Extraction
    /// A file/dir whose presence marks the folder as a project for this agent.
    let isProjectMarker: Bool
}

nonisolated enum LocationRegistry {

    // MARK: Global (relative to home)
    static let global: [GlobalRule] = [
        // Claude Code
        .init(agentKey: "claude", category: .rules,     relPath: ".claude/CLAUDE.md",      format: .md,   extraction: .singleFile),
        .init(agentKey: "claude", category: .mcp,       relPath: ".claude.json",           format: .json, extraction: .mcpServersJSON),
        .init(agentKey: "claude", category: .skills,    relPath: ".claude/skills",         format: .md,   extraction: .skillFolders),
        .init(agentKey: "claude", category: .commands,  relPath: ".claude/commands",       format: .md,   extraction: .markdownGlob),
        .init(agentKey: "claude", category: .subagents, relPath: ".claude/agents",         format: .md,   extraction: .markdownGlob),
        .init(agentKey: "claude", category: .settings,  relPath: ".claude/settings.json",  format: .json, extraction: .singleFile),

        // Cursor
        .init(agentKey: "cursor", category: .mcp,      relPath: ".cursor/mcp.json",        format: .json, extraction: .mcpServersJSON),
        .init(agentKey: "cursor", category: .commands, relPath: ".cursor/commands",        format: .md,   extraction: .markdownGlob),

        // Windsurf
        .init(agentKey: "windsurf", category: .rules, relPath: ".codeium/windsurf/memories/global_rules.md", format: .md,   extraction: .singleFile),
        .init(agentKey: "windsurf", category: .mcp,   relPath: ".codeium/windsurf/mcp_config.json",          format: .json, extraction: .mcpServersJSON),

        // Codex
        .init(agentKey: "codex", category: .rules,    relPath: ".codex/AGENTS.md",   format: .md,   extraction: .singleFile),
        .init(agentKey: "codex", category: .settings, relPath: ".codex/config.toml", format: .toml, extraction: .singleFile),

        // Gemini
        .init(agentKey: "gemini", category: .settings, relPath: ".gemini/settings.json", format: .json, extraction: .singleFile),
        .init(agentKey: "gemini", category: .mcp,      relPath: ".gemini/settings.json", format: .json, extraction: .mcpServersJSON),

        // Continue
        .init(agentKey: "continue", category: .settings, relPath: ".continue/config.yaml", format: .yaml, extraction: .singleFile),

        // Augment
        .init(agentKey: "augment", category: .mcp, relPath: ".augment/mcp.json", format: .json, extraction: .mcpServersJSON),
    ]

    // MARK: Project (relative to a project root)
    static let project: [ProjectRule] = [
        // Claude Code
        .init(agentKey: "claude", category: .rules,     relPath: "CLAUDE.md",          format: .md,   extraction: .singleFile,   isProjectMarker: true),
        .init(agentKey: "claude", category: .mcp,       relPath: ".mcp.json",          format: .json, extraction: .mcpServersJSON, isProjectMarker: true),
        .init(agentKey: "claude", category: .skills,    relPath: ".claude/skills",     format: .md,   extraction: .skillFolders,  isProjectMarker: false),
        .init(agentKey: "claude", category: .commands,  relPath: ".claude/commands",   format: .md,   extraction: .markdownGlob,  isProjectMarker: false),
        .init(agentKey: "claude", category: .subagents, relPath: ".claude/agents",     format: .md,   extraction: .markdownGlob,  isProjectMarker: false),
        .init(agentKey: "claude", category: .settings,  relPath: ".claude/settings.json", format: .json, extraction: .singleFile, isProjectMarker: false),

        // Cursor
        .init(agentKey: "cursor", category: .rules, relPath: ".cursorrules",     format: .md,   extraction: .singleFile, isProjectMarker: true),
        .init(agentKey: "cursor", category: .rules, relPath: ".cursor/rules",    format: .md,   extraction: .mdcGlob,    isProjectMarker: true),
        .init(agentKey: "cursor", category: .mcp,   relPath: ".cursor/mcp.json", format: .json, extraction: .mcpServersJSON, isProjectMarker: true),

        // Windsurf
        .init(agentKey: "windsurf", category: .rules, relPath: ".windsurfrules", format: .md, extraction: .singleFile, isProjectMarker: true),

        // Cline
        .init(agentKey: "cline", category: .rules, relPath: ".clinerules", format: .md, extraction: .singleFile, isProjectMarker: true),

        // Gemini
        .init(agentKey: "gemini", category: .rules, relPath: "GEMINI.md", format: .md, extraction: .singleFile, isProjectMarker: true),

        // Qwen
        .init(agentKey: "qwen", category: .rules, relPath: "QWEN.md", format: .md, extraction: .singleFile, isProjectMarker: true),

        // Augment
        .init(agentKey: "augment", category: .rules, relPath: ".augment/guidelines.md", format: .md, extraction: .singleFile, isProjectMarker: true),

        // generic AGENTS.md
        .init(agentKey: "generic", category: .rules, relPath: "AGENTS.md", format: .md, extraction: .singleFile, isProjectMarker: true),
    ]
}
