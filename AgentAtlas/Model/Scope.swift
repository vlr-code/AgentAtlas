//
//  Scope.swift
//  AgentAtlas
//
//  Domain — where an artifact lives. Global (user-wide) vs Project (named).
//  Override priority is by scope order (§7): Project overrides Global.
//

import Foundation

nonisolated enum Scope: Hashable, Sendable {
    case global
    case project(String)

    var label: String {
        switch self {
        case .global:            return "Global"
        case .project(let name): return name
        }
    }

    var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    /// Lower number = higher priority when resolving overrides.
    var priority: Int { isGlobal ? 1 : 0 }
}
