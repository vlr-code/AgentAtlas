//
//  FixStore.swift
//  AgentAtlas
//
//  Persists the fix history (newest first) and owns the backups directory,
//  both under ~/Library/Application Support/AgentAtlas/.
//

import Foundation

@MainActor
final class FixStore {

    let backupsDir: URL
    private let journalURL: URL
    private(set) var records: [FixRecord] = []

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AgentAtlas", isDirectory: true)
        backupsDir = base.appendingPathComponent("Backups", isDirectory: true)
        journalURL = base.appendingPathComponent("fix-history.json")
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        load()
    }

    func add(_ record: FixRecord) {
        records.insert(record, at: 0)   // newest first
        save()
    }

    func markReverted(_ id: String) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].reverted = true
        // The backup has served its purpose once reverted — free the space.
        if let bp = records[i].backupPath { try? FileManager.default.removeItem(atPath: bp) }
        save()
    }

    /// Wipe all backups and the journal. Anything not yet reverted becomes
    /// non-undoable, so the caller must confirm first.
    func clearAll() {
        if let files = try? FileManager.default.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
        records = []
        save()
    }

    /// Total size of stored backups, for display.
    var backupsByteSize: Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupsDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: journalURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let recs = try? decoder.decode([FixRecord].self, from: data) { records = recs }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(records) {
            try? data.write(to: journalURL, options: .atomic)
        }
    }
}
