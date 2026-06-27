//
//  AppState.swift
//  AgentAtlas
//
//  Shared view-model for the three panes. AppKit has no @Published wiring by
//  default, so panes register a closure via `observe` and are notified on change.
//

import AppKit

@MainActor
final class AppState {

    enum Axis: String, CaseIterable {
        case agent = "By Agent"
        case type  = "By Type"
        case scope = "By Project"
    }

    enum Phase: Equatable {
        case idle
        case scanning
        case populated
        case empty
    }

    struct Group: Hashable {
        let key: String       // e.g. "agent:claude"
        let title: String
        let count: Int
    }

    // MARK: State
    private(set) var artifacts: [Artifact] = []
    private(set) var phase: Phase = .idle
    private(set) var scanProgress = ScanProgress()
    private var scanTask: Task<Void, Never>?

    var axis: Axis = .agent { didSet { if oldValue != axis { selectedGroup = nil; notify() } } }
    var searchText: String = "" { didSet { if oldValue != searchText { notify() } } }
    var selectedGroup: String? { didSet { if oldValue != selectedGroup { notify() } } }
    var selectedArtifactID: Artifact.ID? { didSet { if oldValue != selectedArtifactID { notify() } } }

    // MARK: Observation
    private var observers: [() -> Void] = []
    func observe(_ callback: @escaping () -> Void) { observers.append(callback) }
    private func notify() { observers.forEach { $0() } }

    /// Applied-fix history + backups (phase 2).
    let fixStore = FixStore()

    // MARK: Tweaks & settings (persisted in UserDefaults)
    private let defaults = UserDefaults.standard
    private(set) var density: AADensity = .comfortable
    private(set) var accentIndex = 0
    private(set) var scanDepth = 3
    private(set) var enabledAgentKeys = Set(AgentCatalog.all.map(\.key))

    var listRowHeight: CGFloat { density == .compact ? 46 : 54 }

    init() {
        if let d = defaults.string(forKey: "aa.density") { density = d == "compact" ? .compact : .comfortable }
        accentIndex = (defaults.object(forKey: "aa.accent") as? Int).map { min(max($0, 0), AAColor.accentOptions.count - 1) } ?? 0
        AAColor.accent = AAColor.accentOptions[accentIndex].color
        if defaults.object(forKey: "aa.depth") != nil { scanDepth = max(1, defaults.integer(forKey: "aa.depth")) }
        if let arr = defaults.array(forKey: "aa.agents") as? [String], !arr.isEmpty { enabledAgentKeys = Set(arr) }
    }

    func setDensity(_ d: AADensity) {
        density = d
        defaults.set(d == .compact ? "compact" : "comfortable", forKey: "aa.density")
        notify()
    }
    func setAccent(_ i: Int) {
        accentIndex = i
        AAColor.accent = AAColor.accentOptions[i].color
        defaults.set(i, forKey: "aa.accent")
        notify()
    }
    func setScanDepth(_ n: Int) {
        scanDepth = max(1, n)
        defaults.set(scanDepth, forKey: "aa.depth")
    }
    func setAgentEnabled(_ key: String, _ on: Bool) {
        if on { enabledAgentKeys.insert(key) } else { enabledAgentKeys.remove(key) }
        defaults.set(Array(enabledAgentKeys), forKey: "aa.agents")
    }

    // MARK: Derived — sidebar groups on the active axis
    func groups() -> [Group] {
        switch axis {
        case .agent:
            return AgentCatalog.all.compactMap { agent in
                let count = artifacts.lazy.filter { $0.agentKey == agent.key }.count
                return count > 0 ? Group(key: "agent:\(agent.key)", title: agent.name, count: count) : nil
            }
        case .type:
            return Category.allCases.compactMap { cat in
                let count = artifacts.lazy.filter { $0.category == cat }.count
                return count > 0 ? Group(key: "type:\(cat.rawValue)", title: cat.label, count: count) : nil
            }
        case .scope:
            var groups: [Group] = []
            let globalCount = artifacts.lazy.filter { $0.scope.isGlobal }.count
            if globalCount > 0 { groups.append(Group(key: "scope:Global", title: "Global", count: globalCount)) }
            var seen = Set<String>()
            for a in artifacts where !a.scope.isGlobal {
                let name = a.scope.label
                guard seen.insert(name).inserted else { continue }
                let count = artifacts.lazy.filter { !$0.scope.isGlobal && $0.scope.label == name }.count
                groups.append(Group(key: "scope:\(name)", title: name, count: count))
            }
            return groups
        }
    }

    func groupKey(for a: Artifact) -> String {
        switch axis {
        case .agent: return "agent:\(a.agentKey)"
        case .type:  return "type:\(a.category.rawValue)"
        case .scope: return a.scope.isGlobal ? "scope:Global" : "scope:\(a.scope.label)"
        }
    }

    // MARK: Derived — list contents
    func visibleArtifacts() -> [Artifact] {
        var items = artifacts
        if let group = selectedGroup {
            if group == "__issues__" {
                items = items.filter(\.isIssue)
            } else {
                items = items.filter { groupKey(for: $0) == group }
            }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            items = items.filter { $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query) }
        }
        return items.sorted {
            ($0.agentKey, $0.category.rawValue, $0.name) < ($1.agentKey, $1.category.rawValue, $1.name)
        }
    }

    func artifact(id: Artifact.ID?) -> Artifact? {
        guard let id else { return nil }
        return artifacts.first { $0.id == id }
    }

    var issuesCount: Int { artifacts.lazy.filter(\.isIssue).count }
    var agentsCount: Int { Set(artifacts.map(\.agentKey)).count }

    // MARK: Scan
    func startScan() {
        scanTask?.cancel()   // cancel any in-flight scan before starting a new one
        phase = .scanning
        artifacts = []
        scanProgress = ScanProgress()
        notify()
        let scope = currentScope()
        scanTask = Task.detached(priority: .userInitiated) {
            for await event in Scanner.scanStream(scope) {
                if Task.isCancelled { break }
                switch event {
                case .progress(let p):
                    await MainActor.run { self.scanProgress = p; self.notify() }
                case .batch(let arts):
                    await MainActor.run { self.artifacts.append(contentsOf: arts); self.notify() }
                case .done(let r):
                    await MainActor.run {
                        self.artifacts = r.artifacts
                        self.phase = r.artifacts.isEmpty ? .empty : .populated
                        self.notify()
                    }
                }
            }
        }
    }

    /// Scope from current settings; honors --scan-root / --scan-depth for tests.
    private func currentScope() -> ScanScope {
        var scope = ScanScope.standard
        scope.maxDepth = scanDepth
        scope.agentKeys = enabledAgentKeys
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let root = value("--scan-root") {
            scope.projectSearchRoots = [URL(fileURLWithPath: (root as NSString).expandingTildeInPath)]
        }
        if let d = value("--scan-depth"), let dv = Int(d) { scope.maxDepth = dv }
        return scope
    }
}
