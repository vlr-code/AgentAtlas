//
//  ListViewController.swift
//  AgentAtlas
//
//  The center pane: artifact rows for the current axis group + search.
//  Э3a shows name + meta + path; the styled row (monogram, pills, flag
//  cluster per DESIGN_SYSTEM §5) lands in Э3b.
//

import AppKit

final class ListViewController: NSViewController {

    private let state: AppState
    private let tableView = NSTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var items: [Artifact] = []

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AAColor.s0b.cgColor

        let column = NSTableColumn(identifier: .init("artifact"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 54
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.dataSource = self
        tableView.delegate = self

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = AAFont.body()
        emptyLabel.textColor = AAColor.txMute
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(scroll)
        root.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        state.observe { [weak self] in self?.reload() }
        reload()
    }


    private func reload() {
        items = state.visibleArtifacts()
        tableView.rowHeight = state.listRowHeight
        tableView.reloadData()
        // keep selection in sync
        if let id = state.selectedArtifactID, let idx = items.firstIndex(where: { $0.id == id }) {
            if tableView.selectedRow != idx {
                tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            }
        } else if tableView.selectedRow != -1 {
            tableView.deselectAll(nil)
        }

        emptyLabel.isHidden = !items.isEmpty
        if items.isEmpty {
            let query = state.searchText.trimmingCharacters(in: .whitespaces)
            if state.phase == .scanning {
                emptyLabel.stringValue = "Scanning…"
            } else if !query.isEmpty {
                emptyLabel.stringValue = "No matches for “\(query)”"
            } else {
                emptyLabel.stringValue = "Nothing found"
            }
        }
    }
}

extension ListViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let a = items[row]
        let id = NSUserInterfaceItemIdentifier("artifactRow")
        let cell: ArtifactRowView = (tableView.makeView(withIdentifier: id, owner: self) as? ArtifactRowView) ?? {
            let c = ArtifactRowView()
            c.identifier = id
            return c
        }()
        cell.configure(with: a)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let r = tableView.selectedRow
        state.selectedArtifactID = (r >= 0 && r < items.count) ? items[r].id : nil
    }
}

/// Two-line artifact row (DESIGN_SYSTEM §5, adapted):
///   line 1: monogram · category glyph · name · format tag · scope pill · flag cluster
///   line 2: file path — clickable, reveals in Finder.
private final class ArtifactRowView: NSTableCellView {
    private let agentIcon = NSImageView()          // plain NSImageView in the stack — renders like categoryIcon
    private let agentLetter = NSTextField(labelWithString: "") // fallback for agents without an icon
    private let categoryIcon = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let formatTag = FormatTagView()
    private let scopePill = ScopePillView()
    private let flagCluster = FlagClusterView()
    private let pathField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        agentIcon.imageScaling = .scaleProportionallyUpOrDown
        agentIcon.translatesAutoresizingMaskIntoConstraints = false
        agentIcon.setContentHuggingPriority(.required, for: .horizontal)
        agentIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        agentIcon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        agentLetter.alignment = .center
        agentLetter.font = .systemFont(ofSize: 10, weight: .bold)
        agentLetter.translatesAutoresizingMaskIntoConstraints = false
        agentLetter.setContentHuggingPriority(.required, for: .horizontal)
        agentLetter.wantsLayer = true
        agentLetter.layer?.cornerRadius = 5
        agentLetter.layer?.masksToBounds = true
        agentLetter.widthAnchor.constraint(equalToConstant: 20).isActive = true
        agentLetter.heightAnchor.constraint(equalToConstant: 20).isActive = true

        categoryIcon.translatesAutoresizingMaskIntoConstraints = false
        categoryIcon.setContentHuggingPriority(.required, for: .horizontal)
        categoryIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        nameField.lineBreakMode = .byTruncatingTail
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // truncate, never force width
        nameField.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        let topRow = NSStackView(views: [agentIcon, agentLetter, categoryIcon, nameField, formatTag, scopePill, spacer, flagCluster])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 7
        topRow.translatesAutoresizingMaskIntoConstraints = false

        pathField.font = AAFont.mono(11.5)
        pathField.textColor = AAColor.txDim
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let vstack = NSStackView(views: [topRow, pathField])
        vstack.orientation = .vertical
        vstack.alignment = .leading
        vstack.spacing = 3
        vstack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(vstack)
        NSLayoutConstraint.activate([
            vstack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            vstack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            vstack.centerYAnchor.constraint(equalTo: centerYAnchor),

            topRow.widthAnchor.constraint(equalTo: vstack.widthAnchor),
            pathField.widthAnchor.constraint(equalTo: vstack.widthAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with a: Artifact) {
        if let icon = NSImage(named: a.agentKey) {
            agentIcon.image = roundedImage(icon, side: 20, radius: 5)
            agentIcon.isHidden = false
            agentLetter.isHidden = true
        } else {
            agentIcon.image = nil
            agentIcon.isHidden = true
            agentLetter.isHidden = false
            agentLetter.stringValue = a.agent.mono
            let tile = a.agent.tile
            agentLetter.layer?.backgroundColor = tile.fill.cgColor
            agentLetter.layer?.borderColor = tile.border.cgColor
            agentLetter.layer?.borderWidth = 0.75
            agentLetter.textColor = tile.glyph
        }

        let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        categoryIcon.image = NSImage(systemSymbolName: categorySymbolName(a.category), accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        categoryIcon.contentTintColor = AAColor.txDim

        nameField.stringValue = a.name
        nameField.font = a.nameIsMono ? AAFont.mono(13.5, weight: .medium) : AAFont.bodyMedium(14)
        nameField.textColor = AAColor.tx

        formatTag.configure(format: a.format)
        scopePill.configure(scope: a.scope)
        flagCluster.configure(flags: a.flags, broken: a.broken)
        pathField.stringValue = a.path

        alphaValue = a.isEnabled ? 1.0 : 0.55
    }
}
