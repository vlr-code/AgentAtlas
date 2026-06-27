//
//  Scanner.swift
//  AgentAtlas
//
//  Walks the global locations and discovered projects, applies each
//  extraction rule, streams results as they're found, then post-processes
//  cross-artifact flags (duplicate / conflict / overrides) for the final
//  result. Synchronous file IO — run off-main.
//

import Foundation

nonisolated struct ScanProgress: Sendable {
    var foldersScanned = 0
    var filesSeen = 0
    var agentsFound = 0
    var currentPath = ""
}

nonisolated struct ScanStats: Sendable {
    let agents: Int
    let artifacts: Int
    let issues: Int
}

nonisolated struct ScanResult: Sendable {
    let artifacts: [Artifact]
    let stats: ScanStats
    var foldersVisited = 0
    var hitFolderCap = false
}

nonisolated enum ScanEvent: Sendable {
    case progress(ScanProgress)
    case batch([Artifact])       // raw artifacts as found (no cross-flags yet)
    case done(ScanResult)        // final list with all flags computed
}

nonisolated enum Scanner {

    /// Stream scan events as work proceeds. The consumer runs it off-main.
    static func scanStream(_ scope: ScanScope) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await runStreaming(scope) { continuation.yield($0) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Run a full scan to completion (used by the headless dump). Off-main.
    static func scanToCompletion(_ scope: ScanScope,
                                 progress: (@Sendable (ScanProgress) -> Void)? = nil) async -> ScanResult {
        var result = ScanResult(artifacts: [], stats: ScanStats(agents: 0, artifacts: 0, issues: 0))
        for await event in scanStream(scope) {
            switch event {
            case .progress(let p): progress?(p)
            case .done(let r): result = r
            case .batch: break
            }
        }
        return result
    }

    // MARK: - Producer

    private static func runStreaming(_ scope: ScanScope, emit: @escaping @Sendable (ScanEvent) -> Void) async {
        let fm = FileManager.default
        let home = scope.home.path
        var all: [Artifact] = []
        var prog = ScanProgress()

        // 1. Global locations
        var globalArtifacts: [Artifact] = []
        for rule in LocationRegistry.global where scope.agentKeys.contains(rule.agentKey) {
            if Task.isCancelled { break }
            let base = scope.home.appendingPathComponent(rule.relPath)
            globalArtifacts.append(contentsOf: apply(extraction: rule.extraction, at: base,
                agentKey: rule.agentKey, category: rule.category, format: rule.format,
                scope: .global, home: home, fm: fm, prog: &prog))
        }
        if !globalArtifacts.isEmpty { all.append(contentsOf: globalArtifacts); emit(.batch(globalArtifacts)) }
        emit(.progress(prog))

        // 2. Discover projects (progress reported from the count arg — no shared mutable capture)
        let globalFiles = prog.filesSeen
        let outcome = ProjectFinder.find(scope) { count, path in
            if count % 25 == 0 {
                var p = ScanProgress()
                p.foldersScanned = count
                p.filesSeen = globalFiles
                p.currentPath = path
                emit(.progress(p))
            }
        }
        prog.foldersScanned = outcome.foldersVisited

        // 3. Project locations — one batch per project for a live feel
        for project in outcome.projects {
            if Task.isCancelled { break }
            var projectArtifacts: [Artifact] = []
            for rule in LocationRegistry.project where scope.agentKeys.contains(rule.agentKey) {
                let base = project.url.appendingPathComponent(rule.relPath)
                projectArtifacts.append(contentsOf: apply(extraction: rule.extraction, at: base,
                    agentKey: rule.agentKey, category: rule.category, format: rule.format,
                    scope: .project(project.name), home: home, fm: fm, prog: &prog))
            }
            if !projectArtifacts.isEmpty {
                all.append(contentsOf: projectArtifacts)
                emit(.batch(projectArtifacts))
            }
            prog.currentPath = project.url.path
            emit(.progress(prog))
        }

        // 4. Cross-artifact flags + final result
        let flagged = postProcess(all)
        let issues = flagged.filter(\.isIssue).count
        let agents = Set(flagged.map(\.agentKey)).count
        prog.agentsFound = agents
        emit(.progress(prog))
        emit(.done(ScanResult(
            artifacts: flagged,
            stats: ScanStats(agents: agents, artifacts: flagged.count, issues: issues),
            foldersVisited: outcome.foldersVisited, hitFolderCap: outcome.hitFolderCap)))
    }

    // MARK: - Extraction

    private static func apply(extraction: Extraction, at base: URL,
                              agentKey: String, category: Category, format: FileFormat,
                              scope: Scope, home: String, fm: FileManager,
                              prog: inout ScanProgress) -> [Artifact] {
        switch extraction {
        case .singleFile:
            guard entryExists(base.path, fm) else { return [] }
            prog.filesSeen += 1
            return [makeArtifact(agentKey: agentKey, category: category, scope: scope,
                                 fileURL: base, name: base.lastPathComponent, format: format,
                                 home: home, fm: fm)]

        case .mcpServersJSON:
            guard entryExists(base.path, fm) else { return [] }
            prog.filesSeen += 1
            guard let entries = ConfigParsers.mcpServers(at: base) else {
                var a = makeArtifact(agentKey: agentKey, category: .mcp, scope: scope,
                                     fileURL: base, name: base.lastPathComponent, format: format,
                                     home: home, fm: fm)
                a.flags.insert(.parseError)
                return [a]
            }
            return entries.map { entry in
                var a = makeArtifact(agentKey: agentKey, category: .mcp, scope: scope,
                                     fileURL: base, name: entry.name, format: format,
                                     home: home, fm: fm, idSuffix: entry.name)
                if entry.disabled { a.flags.insert(.disabled) }
                return a
            }

        case .markdownGlob:
            return mdFiles(in: base, ext: "md", fm: fm).map { url in
                prog.filesSeen += 1
                let fmName = ConfigParsers.frontmatter(at: url).name
                return makeArtifact(agentKey: agentKey, category: category, scope: scope,
                                    fileURL: url, name: fmName ?? url.deletingPathExtension().lastPathComponent,
                                    format: format, home: home, fm: fm)
            }

        case .mdcGlob:
            return mdFiles(in: base, ext: "mdc", fm: fm).map { url in
                prog.filesSeen += 1
                return makeArtifact(agentKey: agentKey, category: category, scope: scope,
                                    fileURL: url, name: url.lastPathComponent, format: format,
                                    home: home, fm: fm)
            }

        case .skillFolders:
            guard let subdirs = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
            var out: [Artifact] = []
            for dir in subdirs {
                let skill = dir.appendingPathComponent("SKILL.md")
                guard entryExists(skill.path, fm) else { continue }
                prog.filesSeen += 1
                let fmName = ConfigParsers.frontmatter(at: skill).name
                out.append(makeArtifact(agentKey: agentKey, category: category, scope: scope,
                                        fileURL: skill, name: fmName ?? dir.lastPathComponent,
                                        format: format, home: home, fm: fm))
            }
            return out
        }
    }

    private static func mdFiles(in dir: URL, ext: String, fm: FileManager) -> [URL] {
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return items.filter { $0.pathExtension.lowercased() == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Artifact builder (handles symlink detection)

    private static func makeArtifact(agentKey: String, category: Category, scope: Scope,
                                     fileURL: URL, name: String, format: FileFormat,
                                     home: String, fm: FileManager, idSuffix: String = "") -> Artifact {
        var flags: Set<Flag> = []
        var symlinkTo: String?
        var broken = false

        if let dest = try? fm.destinationOfSymbolicLink(atPath: fileURL.path) {
            flags.insert(.symlink)
            symlinkTo = abbreviate(dest, home: home)
            if !fm.fileExists(atPath: fileURL.resolvingSymlinksInPath().path) { broken = true }
        }

        let display = abbreviate(fileURL.path, home: home)
        let id = fileURL.path + (idSuffix.isEmpty ? "" : "#" + idSuffix)
        return Artifact(id: id, name: name, agentKey: agentKey, category: category,
                        scope: scope, path: display, realPath: fileURL.path, format: format,
                        flags: flags, symlinkTo: symlinkTo, overrides: nil, broken: broken)
    }

    private static func abbreviate(_ path: String, home: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// True if a filesystem entry exists at `path`, including a broken symlink.
    /// (`fileExists` follows links and returns false for dangling ones, which
    /// would silently drop broken-symlink artifacts — a Health feature.)
    private static func entryExists(_ path: String, _ fm: FileManager) -> Bool {
        fm.fileExists(atPath: path) || (try? fm.destinationOfSymbolicLink(atPath: path)) != nil
    }

    // MARK: - Cross-artifact flags

    private static func postProcess(_ input: [Artifact]) -> [Artifact] {
        var artifacts = input

        // Duplicate: a user-named artifact (mcp / command / skill / subagent) with the
        // same name configured across 2+ different agents. Framework-fixed filenames
        // (settings, rules) are excluded — their name collisions are meaningless.
        let dupCategories: Set<Category> = [.mcp, .commands, .skills, .subagents]
        var agentsForName: [String: Set<String>] = [:]
        for a in artifacts where dupCategories.contains(a.category) {
            agentsForName["\(a.category.rawValue)|\(a.name)", default: []].insert(a.agentKey)
        }

        // Override: a project artifact shadows a global one of the same agent+category+name.
        let globalKeys = Set(artifacts.filter { $0.scope.isGlobal }
            .map { "\($0.agentKey)|\($0.category.rawValue)|\($0.name)" })

        for i in artifacts.indices {
            let a = artifacts[i]
            if dupCategories.contains(a.category),
               (agentsForName["\(a.category.rawValue)|\(a.name)"]?.count ?? 0) >= 2 {
                artifacts[i].flags.insert(.duplicate)
            }
            if !a.scope.isGlobal,
               globalKeys.contains("\(a.agentKey)|\(a.category.rawValue)|\(a.name)") {
                artifacts[i].flags.insert(.conflict)
                artifacts[i].flags.insert(.overrides)
                artifacts[i].overrides = "Global"
            }
        }
        return artifacts
    }
}
