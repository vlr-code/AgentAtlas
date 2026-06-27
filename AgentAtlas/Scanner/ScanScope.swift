//
//  ScanScope.swift
//  AgentAtlas
//
//  Configuration for a scan: where to look, how deep, what to skip.
//  The onboarding screen (Э4) edits this; `standard` is the default.
//

import Foundation

nonisolated struct ScanScope: Sendable {
    /// Home directory — global agent configs are resolved relative to it.
    var home: URL
    /// Roots under which to discover project folders.
    var projectSearchRoots: [URL]
    /// Max directory depth for project discovery (relative to each root).
    var maxDepth: Int
    /// Hard cap on folders visited during project discovery (runaway guard).
    var maxFolders: Int
    /// Directory names never descended into.
    var excludedDirNames: Set<String>
    /// Agent keys to include.
    var agentKeys: Set<String>

    static var standard: ScanScope {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ScanScope(
            home: home,
            projectSearchRoots: [home],
            maxDepth: 3,
            maxFolders: 20000,
            excludedDirNames: [
                "node_modules", ".git", "Library", ".Trash", "DerivedData",
                "build", ".build", "Pods", ".next", "dist", "vendor",
                ".venv", "venv", "__pycache__", ".gradle", "Pictures", "Movies",
                "Music", "Applications", "Public", ".npm", ".cache", "Caches",
                // iCloud/TCC-backed dirs can stall directory listing — skipped by default
                "Desktop", "Documents", "Downloads",
            ],
            agentKeys: Set(AgentCatalog.all.map(\.key))
        )
    }
}
