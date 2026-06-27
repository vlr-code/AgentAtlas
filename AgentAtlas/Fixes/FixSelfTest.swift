//
//  FixSelfTest.swift
//  AgentAtlas
//
//  `--selftest-fixes`: exercises every fix apply→revert on a throwaway fixture
//  and verifies the original is restored exactly. A real gate for the only code
//  that writes to the user's config files.
//

import Foundation

nonisolated enum FixSelfTest {

    static func runAndExit() -> Never {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("aa-fixtest-\(UUID().uuidString)")
        let backups = tmp.appendingPathComponent("backups")
        try? fm.createDirectory(at: backups, withIntermediateDirectories: true)

        var ok = true
        func check(_ c: Bool, _ name: String) {
            ok = ok && c
            FileHandle.standardError.write(Data("\(c ? "PASS" : "FAIL")  \(name)\n".utf8))
        }
        func mcpEntry(_ url: URL, _ server: String) -> [String: Any]? {
            guard let d = try? Data(contentsOf: url),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let s = o["mcpServers"] as? [String: Any] else { return nil }
            return s[server] as? [String: Any]
        }

        // 1. enableDisabled — edit JSON, keep siblings, revert exactly
        let mcp = tmp.appendingPathComponent("mcp.json")
        try? #"{"mcpServers":{"pg":{"command":"x","disabled":true},"keep":{"command":"y"}}}"#
            .write(to: mcp, atomically: true, encoding: .utf8)
        let aDis = Artifact(id: "1", name: "pg", agentKey: "claude", category: .mcp, scope: .global,
                            path: mcp.path, realPath: mcp.path, format: .json, flags: [.disabled])
        if let rec = Fixer.apply(.enableDisabled, to: aDis, backupsDir: backups) {
            check(mcpEntry(mcp, "pg")?["disabled"] == nil, "enable: disabled removed")
            check(mcpEntry(mcp, "keep") != nil, "enable: other server kept")
            _ = Fixer.revert(rec)
            check((mcpEntry(mcp, "pg")?["disabled"] as? Bool) == true, "enable: reverted")
        } else { check(false, "enable applied") }

        // 2. removeBrokenSymlink — remove link, recreate on revert
        let link = tmp.appendingPathComponent("CLAUDE.md")
        try? fm.createSymbolicLink(atPath: link.path, withDestinationPath: "/does/not/exist")
        let aBrk = Artifact(id: "2", name: "CLAUDE.md", agentKey: "claude", category: .rules, scope: .global,
                            path: link.path, realPath: link.path, format: .md, flags: [.symlink],
                            symlinkTo: "/does/not/exist", broken: true)
        if let rec = Fixer.apply(.removeBrokenSymlink, to: aBrk, backupsDir: backups) {
            check((try? fm.destinationOfSymbolicLink(atPath: link.path)) == nil, "symlink: removed")
            _ = Fixer.revert(rec)
            check((try? fm.destinationOfSymbolicLink(atPath: link.path)) == "/does/not/exist", "symlink: reverted")
        } else { check(false, "symlink applied") }

        // 3. removeDuplicate (file) — delete, restore content on revert
        let dup = tmp.appendingPathComponent("dup.md")
        try? "hello".write(to: dup, atomically: true, encoding: .utf8)
        let aDup = Artifact(id: "3", name: "dup", agentKey: "claude", category: .commands, scope: .global,
                            path: dup.path, realPath: dup.path, format: .md, flags: [.duplicate])
        if let rec = Fixer.apply(.removeDuplicate, to: aDup, backupsDir: backups) {
            check(!fm.fileExists(atPath: dup.path), "duplicate: removed")
            _ = Fixer.revert(rec)
            check((try? String(contentsOf: dup, encoding: .utf8)) == "hello", "duplicate: reverted")
        } else { check(false, "duplicate applied") }

        try? fm.removeItem(at: tmp)
        FileHandle.standardOutput.write(Data((ok ? "ALL PASS\n" : "SOME FAILED\n").utf8))
        exit(ok ? 0 : 1)
    }
}
