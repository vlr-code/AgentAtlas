//
//  ScanDump.swift
//  AgentAtlas
//
//  Headless `--scan-dump` path: runs a scan to completion and prints a
//  text report, without starting NSApplication. A real machine gate for
//  the scanner core (the binary is driven over stdout from the shell).
//
//  Flags: --root <path>  --depth <n>  --cap <n>  --verbose
//

import Foundation

nonisolated enum ScanDump {

    static func runAndExit() -> Never {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }

        var scope = ScanScope.standard
        if let root = value("--root") {
            scope.projectSearchRoots = [URL(fileURLWithPath: (root as NSString).expandingTildeInPath)]
        }
        if let d = value("--depth"), let dv = Int(d) { scope.maxDepth = dv }
        if let c = value("--cap"), let cv = Int(c) { scope.maxFolders = cv }
        let verbose = args.contains("--verbose")

        let done = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            let result = await Scanner.scanToCompletion(scope) { p in
                if verbose && p.foldersScanned % 200 == 0 {
                    FileHandle.standardError.write(Data("  \(p.foldersScanned)  \(p.currentPath)\n".utf8))
                }
            }
            FileHandle.standardOutput.write(Data(format(result, scope: scope).utf8))
            done.signal()
        }
        done.wait()
        exit(0)
    }

    private static func format(_ result: ScanResult, scope: ScanScope) -> String {
        var out = "=== AgentAtlas scan dump ===\n"
        out += "roots: \(scope.projectSearchRoots.map(\.path).joined(separator: ", "))  depth: \(scope.maxDepth)\n"
        out += "folders: \(result.foldersVisited)\(result.hitFolderCap ? "  (CAP HIT)" : "")\n"
        out += "agents: \(result.stats.agents)  artifacts: \(result.stats.artifacts)  issues: \(result.stats.issues)\n"
        for agent in AgentCatalog.all {
            let items = result.artifacts.filter { $0.agentKey == agent.key }
            guard !items.isEmpty else { continue }
            out += "\n[\(agent.name)] \(items.count)\n"
            for a in items.sorted(by: { ($0.category.rawValue, $0.name) < ($1.category.rawValue, $1.name) }) {
                let flags = a.flags.isEmpty ? "" : "  {\(a.flags.map(\.rawValue).sorted().joined(separator: ","))}"
                out += "  \(a.category.rawValue)/\(a.scope.label): \(a.name)  — \(a.path)\(flags)\n"
            }
        }
        return out
    }
}
