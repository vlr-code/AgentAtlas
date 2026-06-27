//
//  ProjectFinder.swift
//  AgentAtlas
//
//  Discovers project folders under the scan roots by looking for agent
//  markers (CLAUDE.md, .cursor, .git, …). Stops descending once a folder
//  is recognized as a project; never recurses into excluded/hidden/symlinked
//  dirs (so the tree is acyclic and needs no visited-set), and is bounded by
//  scope.maxFolders.
//

import Foundation

nonisolated enum ProjectFinder {

    struct Project: Sendable, Hashable {
        let url: URL
        let name: String
    }

    struct Outcome: Sendable {
        var projects: [Project]
        var foldersVisited: Int
        var hitFolderCap: Bool
    }

    /// Safety cap on number of projects recorded.
    static let maxProjects = 800

    static func find(_ scope: ScanScope, onFolder: (@Sendable (Int, String) -> Void)? = nil) -> Outcome {
        let markers = projectMarkers()
        var found: [Project] = []
        var visited = 0
        var capped = false

        for root in scope.projectSearchRoots {
            walk(root, depth: 0, scope: scope, markers: markers,
                 found: &found, visited: &visited, capped: &capped, onFolder: onFolder)
        }
        let sorted = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Outcome(projects: sorted, foldersVisited: visited, hitFolderCap: capped)
    }

    /// First path component of every project marker rule, plus `.git`.
    private static func projectMarkers() -> Set<String> {
        var set: Set<String> = [".git"]
        for rule in LocationRegistry.project where rule.isProjectMarker {
            if let head = rule.relPath.split(separator: "/").first {
                set.insert(String(head))
            }
        }
        return set
    }

    private static let bundleExtensions: Set<String> = [
        "app", "xcodeproj", "xcworkspace", "bundle", "framework", "playground", "photoslibrary",
    ]

    private static func walk(_ dir: URL,
                             depth: Int,
                             scope: ScanScope,
                             markers: Set<String>,
                             found: inout [Project],
                             visited: inout Int,
                             capped: inout Bool,
                             onFolder: (@Sendable (Int, String) -> Void)?) {
        if found.count >= maxProjects { return }
        if visited >= scope.maxFolders { capped = true; return }
        if Task.isCancelled { return }

        visited += 1
        onFolder?(visited, dir.path)

        let children = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []

        // A folder below a root that holds any marker IS a project — record and stop.
        if depth > 0 && !Set(children).isDisjoint(with: markers) {
            found.append(Project(url: dir, name: dir.lastPathComponent))
            return
        }

        guard depth < scope.maxDepth else { return }

        for child in children {
            if child.hasPrefix(".") { continue }                       // skip hidden when descending
            if scope.excludedDirNames.contains(child) { continue }

            let childURL = dir.appendingPathComponent(child)
            if bundleExtensions.contains(childURL.pathExtension.lowercased()) { continue }

            // One stat: must be a real directory, not a symlink (avoids cycles).
            guard let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true else { continue }

            walk(childURL, depth: depth + 1, scope: scope, markers: markers,
                 found: &found, visited: &visited, capped: &capped, onFolder: onFolder)
        }
    }
}
