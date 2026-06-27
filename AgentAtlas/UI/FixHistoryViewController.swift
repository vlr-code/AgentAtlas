//
//  FixHistoryViewController.swift
//  AgentAtlas
//
//  Sheet listing every applied fix (newest first) with a per-entry Revert.
//

import AppKit

final class FixHistoryViewController: NSViewController {

    private let state: AppState
    private let listStack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No fixes applied yet.")
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AAColor.winBg.cgColor

        let title = NSTextField(labelWithString: "Fix history")
        title.font = AAFont.title()
        title.textColor = AAColor.tx
        title.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = AAFont.body()
        emptyLabel.textColor = AAColor.txMute
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 8
        listStack.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(listStack)
        let scroll = NSScrollView()
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let done = NSButton(title: "Done", target: self, action: #selector(closeSheet))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false

        let clear = NSButton(title: "Clear history", target: self, action: #selector(clearHistory))
        clear.bezelStyle = .rounded
        clear.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(scroll)
        root.addSubview(emptyLabel)
        root.addSubview(done)
        root.addSubview(clear)

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 480),
            root.heightAnchor.constraint(equalToConstant: 460),

            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),

            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: done.topAnchor, constant: -12),

            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),

            doc.topAnchor.constraint(equalTo: scroll.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.widthAnchor),

            listStack.topAnchor.constraint(equalTo: doc.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            listStack.bottomAnchor.constraint(lessThanOrEqualTo: doc.bottomAnchor),

            done.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            done.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),

            clear.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            clear.centerYAnchor.constraint(equalTo: done.centerYAnchor),
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reload()
    }

    private func reload() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !state.fixStore.records.isEmpty
        for record in state.fixStore.records {
            let row = makeRow(record)
            listStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: listStack.widthAnchor).isActive = true
        }
    }

    private func makeRow(_ r: FixRecord) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = AAColor.s1.cgColor
        container.layer?.cornerRadius = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let summary = NSTextField(labelWithString: r.summary)
        summary.font = AAFont.bodyMedium(12.5)
        summary.textColor = r.reverted ? AAColor.txMute : AAColor.tx
        summary.lineBreakMode = .byTruncatingTail

        let path = NSTextField(labelWithString: abbreviate(r.realPath))
        path.font = AAFont.mono(10.5)
        path.textColor = AAColor.txMute
        path.lineBreakMode = .byTruncatingMiddle
        path.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let left = NSStackView(views: [summary, path])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 2
        left.translatesAutoresizingMaskIntoConstraints = false

        let action: NSView
        if r.reverted {
            let l = NSTextField(labelWithString: "Reverted")
            l.font = AAFont.caption()
            l.textColor = AAColor.txMute
            action = l
        } else {
            let b = NSButton(title: "Revert", target: self, action: #selector(revertTapped(_:)))
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.identifier = NSUserInterfaceItemIdentifier(r.id)
            action = b
        }
        action.translatesAutoresizingMaskIntoConstraints = false
        action.setContentHuggingPriority(.required, for: .horizontal)

        container.addSubview(left)
        container.addSubview(action)
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            left.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            left.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
            left.trailingAnchor.constraint(lessThanOrEqualTo: action.leadingAnchor, constant: -10),
            action.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            action.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    @objc private func revertTapped(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let record = state.fixStore.records.first(where: { $0.id == id }) else { return }
        if Fixer.revert(record) {
            state.fixStore.markReverted(id)
            state.startScan()
            reload()
        } else {
            let fail = NSAlert()
            fail.messageText = "Couldn't revert"
            fail.informativeText = "The backup may be missing or the file changed."
            fail.runModal()
        }
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear fix history?"
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(state.fixStore.backupsByteSize), countStyle: .file)
        alert.informativeText = "This deletes all backups (\(sizeStr)). Any fix you haven't reverted can no longer be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        state.fixStore.clearAll()
        reload()
    }

    @objc private func closeSheet() { dismiss(self) }

    private func abbreviate(_ path: String) -> String {
        path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
