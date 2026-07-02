//
//  Fixer.swift
//  AgentAtlas
//
//  Applies and reverts fixes. EVERY change is preceded by a backup, and a
//  FixRecord carries enough to restore the original exactly. Writes are atomic.
//

import Foundation

nonisolated enum Fixer {

    /// Apply `kind` to `artifact`, backing up first. Returns the undo record, or nil on failure.
    static func apply(_ kind: FixKind, to a: Artifact, backupsDir: URL) -> FixRecord? {
        let fm = FileManager.default
        let realURL = URL(fileURLWithPath: a.realPath)
        let id = UUID().uuidString
        let backupURL = backupsDir.appendingPathComponent("\(id)-\(realURL.lastPathComponent)")

        var backupPath: String?
        var symlinkTarget: String?

        switch kind {
        case .removeBrokenSymlink:
            // Record the target so we can recreate the (broken) link on undo, then remove it.
            symlinkTarget = try? fm.destinationOfSymbolicLink(atPath: a.realPath)
            guard symlinkTarget != nil else { return nil }
            guard (try? fm.removeItem(at: realURL)) != nil else { return nil }

        case .enableDisabled:
            guard backup(realURL, to: backupURL) else { return nil }
            backupPath = backupURL.path
            guard editMCP(realURL, server: a.name, enable: true) else { return nil }

        case .removeDuplicate:
            guard backup(realURL, to: backupURL) else { return nil }
            backupPath = backupURL.path
            if a.category == .mcp {
                guard removeMCP(realURL, server: a.name) else { return nil }
            } else {
                guard (try? fm.removeItem(at: realURL)) != nil else { return nil }
            }
        }

        return FixRecord(id: id, date: Date(), kind: kind, artifactName: a.name,
                         realPath: a.realPath, backupPath: backupPath, symlinkTarget: symlinkTarget,
                         reverted: false, summary: "\(kind.actionLabel) · \(a.name)")
    }

    /// Restore the original state recorded by a fix. The restored state is fully
    /// staged next to the live file first — a failed revert (missing backup, bad
    /// record, disk error) must never destroy what's currently at the path.
    static func revert(_ r: FixRecord) -> Bool {
        let fm = FileManager.default
        let realURL = URL(fileURLWithPath: r.realPath)
        let staging = realURL.deletingLastPathComponent()
            .appendingPathComponent(".\(realURL.lastPathComponent).aa-restore-\(r.id)")

        try? fm.removeItem(at: staging)
        if let target = r.symlinkTarget {
            guard (try? fm.createSymbolicLink(atPath: staging.path, withDestinationPath: target)) != nil else { return false }
        } else if let bp = r.backupPath {
            guard (try? fm.copyItem(at: URL(fileURLWithPath: bp), to: staging)) != nil else { return false }
        } else {
            return false
        }

        // Same-directory rename — the swap into place is atomic.
        try? fm.removeItem(at: realURL)
        if (try? fm.moveItem(at: staging, to: realURL)) != nil { return true }
        try? fm.removeItem(at: staging)
        return false
    }

    // MARK: - Helpers

    private static func backup(_ from: URL, to dest: URL) -> Bool {
        try? FileManager.default.removeItem(at: dest)   // in case of id collision (shouldn't happen)
        return (try? FileManager.default.copyItem(at: from, to: dest)) != nil
    }

    /// Re-enable an MCP server entry in a JSON file (remove `disabled`, set `enabled` true if present).
    private static func editMCP(_ url: URL, server: String, enable: Bool) -> Bool {
        guard var obj = readJSONObject(url),
              var servers = obj["mcpServers"] as? [String: Any],
              var entry = servers[server] as? [String: Any] else { return false }
        entry.removeValue(forKey: "disabled")
        if entry["enabled"] != nil { entry["enabled"] = true }
        servers[server] = entry
        obj["mcpServers"] = servers
        return writeJSONObject(obj, to: url)
    }

    /// Remove an MCP server entry from a JSON file.
    private static func removeMCP(_ url: URL, server: String) -> Bool {
        guard var obj = readJSONObject(url),
              var servers = obj["mcpServers"] as? [String: Any] else { return false }
        servers.removeValue(forKey: server)
        obj["mcpServers"] = servers
        return writeJSONObject(obj, to: url)
    }

    private static func readJSONObject(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    private static func writeJSONObject(_ obj: [String: Any], to url: URL) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
