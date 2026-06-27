//
//  FixModel.swift
//  AgentAtlas
//
//  Phase 2: safe, reversible auto-fixes for Health issues.
//

import Foundation

nonisolated enum FixKind: String, Codable, Sendable {
    case enableDisabled
    case removeBrokenSymlink
    case removeDuplicate

    /// Button label shown in the detail panel.
    var actionLabel: String {
        switch self {
        case .enableDisabled:      return "Enable"
        case .removeBrokenSymlink: return "Remove broken link"
        case .removeDuplicate:     return "Remove duplicate"
        }
    }

    var verb: String {
        switch self {
        case .enableDisabled:      return "Enable"
        case .removeBrokenSymlink: return "Remove the broken link"
        case .removeDuplicate:     return "Remove the duplicate"
        }
    }
}

/// One applied fix — the audit/undo record (persisted as JSON).
nonisolated struct FixRecord: Codable, Identifiable, Sendable {
    let id: String
    let date: Date
    let kind: FixKind
    let artifactName: String
    let realPath: String          // file that was changed
    let backupPath: String?       // copy of the original (for file edits / deletes)
    let symlinkTarget: String?    // original symlink destination (for symlink restore)
    var reverted: Bool
    let summary: String
}

/// The single fix that applies to an artifact's issue, if any. Priority:
/// broken symlink → disabled → duplicate. conflict/parseError are advice-only.
nonisolated func applicableFix(for a: Artifact) -> FixKind? {
    if a.flags.contains(.symlink), a.broken { return .removeBrokenSymlink }
    if a.flags.contains(.disabled) { return .enableDisabled }
    if a.flags.contains(.duplicate) { return .removeDuplicate }
    return nil
}
