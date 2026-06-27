//
//  ConfigParsers.swift
//  AgentAtlas
//
//  Minimal, dependency-free parsers: MCP servers from JSON, and YAML/TOML
//  frontmatter name/description from Markdown. TOML/YAML server extraction
//  is deferred (those files surface as single settings artifacts for now).
//

import Foundation

nonisolated enum ConfigParsers {

    struct MCPEntry: Sendable {
        let name: String
        let disabled: Bool
    }

    /// MCP servers declared under `mcpServers` in a JSON file.
    /// Returns `nil` if the file can't be read or isn't valid JSON (→ parse error);
    /// returns `[]` for valid JSON with no servers.
    static func mcpServers(at url: URL) -> [MCPEntry]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let root = try? JSONSerialization.jsonObject(with: data),
              let obj = root as? [String: Any] else { return nil }
        guard let servers = obj["mcpServers"] as? [String: Any] else { return [] }
        return servers.map { name, value in
            let dict = value as? [String: Any]
            let disabled = (dict?["disabled"] as? Bool == true)
                || (dict?["enabled"] as? Bool == false)
            return MCPEntry(name: name, disabled: disabled)
        }.sorted { $0.name < $1.name }
    }

    struct MCPDetail: Sendable {
        let command: String?
        let args: [String]
        let envKeys: [String]
        let transport: String?
        let url: String?
    }

    /// Full detail for one MCP server entry (for the detail card).
    static func mcpServerDetail(at url: URL, name: String) -> MCPDetail? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data),
              let obj = root as? [String: Any],
              let servers = obj["mcpServers"] as? [String: Any],
              let s = servers[name] as? [String: Any] else { return nil }
        let command = s["command"] as? String
        let args = (s["args"] as? [Any])?.compactMap { $0 as? String } ?? []
        let envKeys = ((s["env"] as? [String: Any])?.keys).map { Array($0).sorted() } ?? []
        let transport = (s["type"] as? String) ?? (s["transport"] as? String)
        let urlStr = s["url"] as? String
        return MCPDetail(command: command, args: args, envKeys: envKeys, transport: transport, url: urlStr)
    }

    /// `name` / `description` from a leading `--- ... ---` frontmatter block.
    static func frontmatter(at url: URL) -> (name: String?, description: String?) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return (nil, nil) }
        let lines = content.components(separatedBy: .newlines)

        guard let firstNonEmpty = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              firstNonEmpty.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, nil)
        }

        var name: String?
        var description: String?
        var started = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if started { break }
                started = true
                continue
            }
            guard started, let colon = line.range(of: ":") else { continue }
            let key = line[..<colon.lowerBound].trimmingCharacters(in: .whitespaces).lowercased()
            var value = line[colon.upperBound...].trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if key == "name" { name = value }
            if key == "description" { description = value }
        }
        return (name, description)
    }
}
