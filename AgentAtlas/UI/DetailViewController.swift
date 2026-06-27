//
//  DetailViewController.swift
//  AgentAtlas
//
//  Right pane. Header (name, agent·category·scope, description, clickable
//  path) + a yellow "Heads up" box explaining flags, then a category-specific
//  body: MCP card · Markdown (Rendered/Raw) · pretty settings · raw.
//

import AppKit

final class DetailViewController: NSViewController {

    private let state: AppState

    private let placeholder = NSTextField(labelWithString: "Select an item")
    private let titleField = NSTextField(labelWithString: "")
    private let metaField = NSTextField(labelWithString: "")
    private let descField = NSTextField(wrappingLabelWithString: "")
    private let pathField = ClickablePathField()
    private var currentRealPath = ""
    private var currentArtifact: Artifact?
    private let flagsBox = NSView()
    private let flagsStack = NSStackView()
    private let actionsRow = NSStackView()
    private let fixButton = NSButton()
    private let bodyToggle = NSSegmentedControl(labels: ["Rendered", "Raw"], trackingMode: .selectOne, target: nil, action: nil)
    private let contentStack = NSStackView()

    // Body renderers (one visible at a time)
    private let bodyScroll = NSScrollView()
    private let bodyText = NSTextView()
    private let mcpScroll = NSScrollView()
    private let mcpStack = NSStackView()

    private var markdownSource = ""   // for the Rendered/Raw toggle

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AAColor.s0b.cgColor

        placeholder.font = AAFont.body()
        placeholder.textColor = AAColor.txMute
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        titleField.font = AAFont.displaySmall()
        titleField.textColor = AAColor.tx
        titleField.lineBreakMode = .byTruncatingTail
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        metaField.font = AAFont.body(12.5)
        metaField.textColor = AAColor.txDim
        metaField.lineBreakMode = .byTruncatingTail
        metaField.maximumNumberOfLines = 1
        metaField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        descField.font = AAFont.body(12.5)
        descField.textColor = AAColor.txDim
        descField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        pathField.font = AAFont.mono(11.5)
        pathField.textColor = .linkColor
        pathField.toolTip = "Reveal in Finder"
        pathField.onClick = { [weak self] in if let p = self?.currentRealPath { revealInFinder(p) } }

        buildFlagsBox()

        bodyToggle.selectedSegment = 0
        bodyToggle.target = self
        bodyToggle.action = #selector(toggleBody)
        bodyToggle.translatesAutoresizingMaskIntoConstraints = false

        fixButton.bezelStyle = .rounded
        fixButton.controlSize = .small
        fixButton.target = self
        fixButton.action = #selector(applyFix)
        fixButton.contentTintColor = AAColor.good
        let revealButton = NSButton(title: "Reveal in Finder", target: self, action: #selector(revealAction))
        revealButton.bezelStyle = .rounded
        revealButton.controlSize = .small
        let openButton = NSButton(title: "Open", target: self, action: #selector(openAction))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        actionsRow.orientation = .horizontal
        actionsRow.spacing = 8
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        actionsRow.addArrangedSubview(fixButton)
        actionsRow.addArrangedSubview(revealButton)
        actionsRow.addArrangedSubview(openButton)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        for v in [titleField, metaField, descField, pathField, flagsBox, actionsRow, bodyToggle] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentStack.addArrangedSubview(v)
        }
        for v in [titleField, metaField, descField, pathField, flagsBox] {
            v.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }

        // Raw / markdown text body
        bodyText.isEditable = false
        bodyText.drawsBackground = true
        bodyText.backgroundColor = AAColor.s0
        bodyText.textColor = AAColor.txDim
        bodyText.font = AAFont.mono(11.5)
        bodyText.textContainerInset = NSSize(width: 10, height: 10)
        bodyScroll.documentView = bodyText
        bodyScroll.hasVerticalScroller = true
        bodyScroll.drawsBackground = false
        bodyScroll.borderType = .noBorder
        bodyScroll.translatesAutoresizingMaskIntoConstraints = false

        // MCP card body
        mcpStack.orientation = .vertical
        mcpStack.alignment = .leading
        mcpStack.spacing = 12
        mcpStack.translatesAutoresizingMaskIntoConstraints = false
        let mcpDoc = NSView()
        mcpDoc.translatesAutoresizingMaskIntoConstraints = false
        mcpDoc.addSubview(mcpStack)
        mcpScroll.documentView = mcpDoc
        mcpScroll.hasVerticalScroller = true
        mcpScroll.drawsBackground = false
        mcpScroll.borderType = .noBorder
        mcpScroll.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(placeholder)
        root.addSubview(contentStack)
        root.addSubview(bodyScroll)
        root.addSubview(mcpScroll)

        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: root.centerYAnchor),

            contentStack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            bodyScroll.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 10),
            bodyScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            bodyScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            bodyScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            mcpScroll.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 10),
            mcpScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            mcpScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            mcpScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),

            mcpStack.topAnchor.constraint(equalTo: mcpDoc.topAnchor, constant: 4),
            mcpStack.leadingAnchor.constraint(equalTo: mcpDoc.leadingAnchor),
            mcpStack.trailingAnchor.constraint(equalTo: mcpDoc.trailingAnchor),
            mcpStack.bottomAnchor.constraint(lessThanOrEqualTo: mcpDoc.bottomAnchor, constant: -4),
            mcpDoc.widthAnchor.constraint(equalTo: mcpScroll.widthAnchor),
        ])
        view = root
    }

    private func buildFlagsBox() {
        flagsBox.wantsLayer = true
        flagsBox.layer?.cornerRadius = 8
        flagsBox.layer?.borderWidth = 1
        flagsBox.layer?.borderColor = AAColor.warn.withAlphaComponent(0.7).cgColor
        flagsBox.layer?.backgroundColor = AAColor.warn.withAlphaComponent(0.12).cgColor
        flagsBox.translatesAutoresizingMaskIntoConstraints = false
        flagsStack.orientation = .vertical
        flagsStack.alignment = .leading
        flagsStack.spacing = 5
        flagsStack.translatesAutoresizingMaskIntoConstraints = false
        flagsBox.addSubview(flagsStack)
        NSLayoutConstraint.activate([
            flagsStack.topAnchor.constraint(equalTo: flagsBox.topAnchor, constant: 10),
            flagsStack.bottomAnchor.constraint(equalTo: flagsBox.bottomAnchor, constant: -10),
            flagsStack.leadingAnchor.constraint(equalTo: flagsBox.leadingAnchor, constant: 12),
            flagsStack.trailingAnchor.constraint(equalTo: flagsBox.trailingAnchor, constant: -12),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        state.observe { [weak self] in self?.reload() }
        reload()
    }

    private func reload() {
        let artifact = state.artifact(id: state.selectedArtifactID)
        let hasSelection = artifact != nil
        placeholder.isHidden = hasSelection
        contentStack.isHidden = !hasSelection
        guard let a = artifact else {
            bodyScroll.isHidden = true; mcpScroll.isHidden = true
            return
        }
        currentRealPath = a.realPath
        currentArtifact = a
        if let kind = applicableFix(for: a) {
            fixButton.isHidden = false
            fixButton.title = kind.actionLabel
        } else {
            fixButton.isHidden = true
        }

        titleField.stringValue = a.name
        metaField.stringValue = "\(a.agent.name)  ·  \(a.category.label)  ·  \(a.scope.label)  ·  \(a.format.tag)"

        // frontmatter description (skills/commands/subagents)
        let desc = a.format == .md ? ConfigParsers.frontmatter(at: URL(fileURLWithPath: a.realPath)).description : nil
        descField.stringValue = desc ?? ""
        descField.isHidden = (desc == nil)

        if let target = a.symlinkTo {
            pathField.stringValue = "\(a.path)  →  \(target)\(a.broken ? "  (broken)" : "")"
        } else {
            pathField.stringValue = a.path
        }

        populateFlags(a)
        renderBody(a)
    }

    private func renderBody(_ a: Artifact) {
        let isMCP = a.category == .mcp && !a.flags.contains(.parseError)
        if isMCP {
            mcpScroll.isHidden = false
            bodyScroll.isHidden = true
            bodyToggle.isHidden = true
            renderMCPCard(a)
        } else if a.format == .md {
            mcpScroll.isHidden = true
            bodyScroll.isHidden = false
            bodyToggle.isHidden = false
            markdownSource = readFile(a)
            renderMarkdown(rendered: bodyToggle.selectedSegment == 0)
        } else {
            mcpScroll.isHidden = true
            bodyScroll.isHidden = false
            bodyToggle.isHidden = true
            let text = readFile(a)
            setBodyPlain(a.format == .json ? prettyJSON(text) : text)
        }
    }

    @objc private func toggleBody() {
        renderMarkdown(rendered: bodyToggle.selectedSegment == 0)
    }

    @objc private func revealAction() {
        if !currentRealPath.isEmpty { revealInFinder(currentRealPath) }
    }
    @objc private func openAction() {
        if !currentRealPath.isEmpty { NSWorkspace.shared.open(URL(fileURLWithPath: currentRealPath)) }
    }

    @objc private func applyFix() {
        guard let a = currentArtifact, let kind = applicableFix(for: a) else { return }
        let alert = NSAlert()
        alert.messageText = "\(kind.verb)?"
        var info = "A backup is saved first, so you can undo this any time from the fix history.\n\n\(a.path)"
        if a.realPath.hasSuffix(".claude.json") {
            info += "\n\n⚠ This is ~/.claude.json — Claude Code rewrites it live. Close active Claude Code sessions first, or your change may be overwritten."
        }
        alert.informativeText = info
        alert.addButton(withTitle: kind.actionLabel)
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let record = Fixer.apply(kind, to: a, backupsDir: state.fixStore.backupsDir) {
            state.fixStore.add(record)
            state.startScan()   // re-scan to refresh the map
        } else {
            let fail = NSAlert()
            fail.messageText = "Couldn't apply the fix"
            fail.informativeText = "Nothing was changed."
            fail.runModal()
        }
    }

    private func renderMarkdown(rendered: Bool) {
        if rendered,
           let data = String(markdownSource.prefix(60000)).data(using: .utf8),
           let attr = try? NSMutableAttributedString(
                markdown: data,
                options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)) {
            attr.addAttribute(.foregroundColor, value: AAColor.tx,
                              range: NSRange(location: 0, length: attr.length))
            bodyText.textStorage?.setAttributedString(attr)
        } else {
            setBodyPlain(markdownSource)
        }
    }

    /// Replace the whole text storage with plain mono text — fully resets any
    /// attributed runs left over from a previous Rendered markdown view.
    private func setBodyPlain(_ text: String) {
        bodyText.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [
            .font: AAFont.mono(11.5),
            .foregroundColor: AAColor.txDim,
        ]))
    }

    // MARK: - MCP card

    private func renderMCPCard(_ a: Artifact) {
        mcpStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let d = ConfigParsers.mcpServerDetail(at: URL(fileURLWithPath: a.realPath), name: a.name) else {
            mcpStack.addArrangedSubview(mcpRow("Server", a.name))
            return
        }
        mcpStack.addArrangedSubview(mcpRow("Status", a.isEnabled ? "Enabled" : "Disabled",
                                           value: a.isEnabled ? AAColor.good : AAColor.txMute))
        if let t = d.transport { mcpStack.addArrangedSubview(mcpRow("Transport", t)) }
        if let c = d.command {
            let full = ([c] + d.args).joined(separator: " ")
            mcpStack.addArrangedSubview(mcpRow("Command", full, mono: true))
        }
        if let u = d.url { mcpStack.addArrangedSubview(mcpRow("URL", u, mono: true)) }
        if !d.envKeys.isEmpty {
            let env = d.envKeys.map { "\($0) = ••••••" }.joined(separator: "\n")
            mcpStack.addArrangedSubview(mcpRow("Environment", env, mono: true))
        }
    }

    private func mcpRow(_ key: String, _ value: String, value valueColor: NSColor = AAColor.tx, mono: Bool = false) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 3
        row.translatesAutoresizingMaskIntoConstraints = false

        let k = NSTextField(labelWithString: key.uppercased())
        k.font = AAFont.sectionLabel()
        k.textColor = AAColor.txMute

        let v = NSTextField(wrappingLabelWithString: value)
        v.font = mono ? AAFont.mono(12) : AAFont.body(13)
        v.textColor = valueColor
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(k)
        row.addArrangedSubview(v)
        row.widthAnchor.constraint(equalTo: mcpStack.widthAnchor).isActive = true
        v.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        return row
    }

    // MARK: - Flags box

    private func populateFlags(_ a: Artifact) {
        flagsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var flags: [Flag] = [.parseError, .conflict, .overrides, .duplicate, .symlink, .disabled]
            .filter { a.flags.contains($0) }
        if flags.contains(.conflict) { flags.removeAll { $0 == .overrides } }

        guard !flags.isEmpty else { flagsBox.isHidden = true; return }
        flagsBox.isHidden = false

        // Red "Problem" only when something is actually broken; otherwise a
        // neutral "Heads up" note (duplicates / intentional overrides etc.).
        let isProblem = a.broken || a.flags.contains(.parseError)
        let tone = isProblem ? AAColor.danger : AAColor.warn
        flagsBox.layer?.borderColor = tone.withAlphaComponent(0.7).cgColor
        flagsBox.layer?.backgroundColor = tone.withAlphaComponent(0.12).cgColor

        let header = NSTextField(labelWithString: isProblem ? "Problem" : "Heads up")
        header.font = AAFont.bodyMedium(12)
        header.textColor = tone
        flagsStack.addArrangedSubview(header)

        for flag in flags {
            let line = NSTextField(wrappingLabelWithString: "")
            let text = NSMutableAttributedString()
            text.append(NSAttributedString(string: flagTitle(flag, a) + ": ",
                attributes: [.foregroundColor: flag.color, .font: AAFont.bodyMedium(12)]))
            text.append(NSAttributedString(string: flagDescription(flag, a),
                attributes: [.foregroundColor: AAColor.txDim, .font: AAFont.body(12)]))
            if let fix = flagFix(flag, a) {
                text.append(NSAttributedString(string: "\nFix: ",
                    attributes: [.foregroundColor: AAColor.good, .font: AAFont.bodyMedium(12)]))
                text.append(NSAttributedString(string: fix,
                    attributes: [.foregroundColor: AAColor.txDim, .font: AAFont.body(12)]))
            }
            line.attributedStringValue = text
            line.translatesAutoresizingMaskIntoConstraints = false
            flagsStack.addArrangedSubview(line)
            line.widthAnchor.constraint(equalTo: flagsStack.widthAnchor).isActive = true
        }
    }

    // MARK: - Helpers

    private func readFile(_ a: Artifact) -> String {
        guard let data = FileManager.default.contents(atPath: a.realPath),
              let text = String(data: data, encoding: .utf8) else {
            return "(couldn't read the file)"
        }
        if text.count > 60000 { return String(text.prefix(60000)) + "\n…" }
        return text
    }

    private func prettyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return text
        }
        return str
    }
}

/// Short title for a flag in the detail "Heads up" box.
private func flagTitle(_ flag: Flag, _ a: Artifact) -> String {
    switch flag {
    case .parseError: return "Can't read it"
    case .conflict:   return "Overrides the global one"
    case .overrides:  return "Replaces"
    case .duplicate:  return "Duplicate"
    case .symlink:    return a.broken ? "Broken link" : "It's an alias"
    case .disabled:   return "Disabled"
    }
}

/// Plain-words explanation of each flag for the detail "Heads up" box.
private func flagDescription(_ flag: Flag, _ a: Artifact) -> String {
    switch flag {
    case .parseError:
        return "The file is corrupted or isn't valid JSON, so it couldn't be read. The agent will most likely ignore it."
    case .conflict:
        return "In this project this file is the one that's used; the global file with the same name is ignored here. Editing the global one won't affect this project."
    case .overrides:
        return "Replaces: \(a.overrides ?? "Global")."
    case .duplicate:
        return "The exact same name “\(a.name)” is also set up for another agent. You may have configured the same thing twice."
    case .symlink:
        return a.broken
            ? "This is an alias to \(a.symlinkTo ?? "?"), but that file doesn't exist — the link is broken, so the agent won't read it."
            : "This isn't the file itself, but an alias to another one: \(a.symlinkTo ?? "?"). Edit that one, not this."
    case .disabled:
        return "This setting is turned off (disabled): it exists but isn't active."
    }
}

/// A concrete "what to do" suggestion for a flag. Read-only advice — actually
/// applying fixes (writing to config files) is phase 2. nil = nothing to do.
private func flagFix(_ flag: Flag, _ a: Artifact) -> String? {
    switch flag {
    case .parseError: return "Open the file and fix the JSON — check for trailing commas, missing quotes or brackets."
    case .conflict:   return "Usually intentional — the project overrides the global on purpose. If that's not what you want, remove or rename the project file."
    case .overrides:  return nil
    case .duplicate:  return "Keep one definition — remove the copy in the other agent, or give one a different name."
    case .symlink:    return a.broken ? "Repoint the alias to a real file, or delete it — its target is missing." : nil
    case .disabled:   return "Re-enable it in the agent's config if you want it active."
    }
}
