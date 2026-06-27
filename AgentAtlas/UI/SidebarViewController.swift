//
//  SidebarViewController.swift
//  AgentAtlas
//
//  The group tree for the active axis (set from the toolbar) + a footer
//  summary. Selecting a group scopes the list. "All" shows everything.
//

import AppKit

final class SidebarViewController: NSViewController {

    private let state: AppState
    private let tableView = NSTableView()
    private let footer = NSTextField(labelWithString: "")

    private struct Row { let key: String?; let title: String; let count: Int } // key nil = All
    private var rows: [Row] = []

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true

        let column = NSTableColumn(identifier: .init("group"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = 30
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        footer.font = AAFont.caption()
        footer.textColor = AAColor.txMute
        footer.lineBreakMode = .byTruncatingTail
        footer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(scroll)
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        state.observe { [weak self] in self?.reload() }
        reload()
    }

    private func reload() {
        var newRows = [Row(key: nil, title: "All", count: state.artifacts.count)]
        if state.issuesCount > 0 {
            newRows.append(Row(key: "__issues__", title: "Issues", count: state.issuesCount))
        }
        newRows += state.groups().map { Row(key: $0.key, title: $0.title, count: $0.count) }
        rows = newRows
        tableView.reloadData()

        let idx = rows.firstIndex { $0.key == state.selectedGroup } ?? 0
        if tableView.selectedRow != idx {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
        if state.phase == .scanning {
            footer.stringValue = "Scanning… \(state.scanProgress.foldersScanned) folders · \(state.artifacts.count) found"
        } else {
            footer.stringValue = "\(state.agentsCount) agents · \(state.artifacts.count) artifacts · \(state.issuesCount) issues"
        }
    }
}

extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("groupCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
            let c = NSTableCellView()
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingTail
            c.addSubview(tf)
            c.textField = tf
            c.identifier = id
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 6),
                tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            return c
        }()
        let r = rows[row]
        cell.textField?.font = AAFont.body(13.5)
        cell.textField?.textColor = r.key == "__issues__" ? AAColor.warn : AAColor.tx
        cell.textField?.stringValue = "\(r.title)   \(r.count)"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0, tableView.selectedRow < rows.count else { return }
        state.selectedGroup = rows[tableView.selectedRow].key
    }
}
