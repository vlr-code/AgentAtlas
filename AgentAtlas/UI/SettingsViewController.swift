//
//  SettingsViewController.swift
//  AgentAtlas
//
//  Settings + Tweaks sheet: accent color, row density, scan depth, and which
//  agents to scan. Accent/density apply live; depth/agents on the next scan.
//

import AppKit

final class SettingsViewController: NSViewController {

    private let state: AppState
    private var swatches: [SwatchView] = []

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AAColor.winBg.cgColor

        let title = label("Settings", font: AAFont.title(), color: AAColor.tx)

        // Accent
        let accentRow = NSStackView()
        accentRow.orientation = .horizontal
        accentRow.spacing = 9
        for (i, opt) in AAColor.accentOptions.enumerated() {
            let sw = SwatchView(color: opt.color, selected: i == state.accentIndex)
            sw.onClick = { [weak self] in self?.pickAccent(i) }
            swatches.append(sw)
            accentRow.addArrangedSubview(sw)
        }

        // Density
        let density = NSSegmentedControl(labels: ["Compact", "Comfortable"],
                                         trackingMode: .selectOne, target: self, action: #selector(densityChanged))
        density.selectedSegment = state.density == .compact ? 0 : 1
        density.segmentStyle = .texturedRounded

        // Scan depth
        let depth = NSSegmentedControl(labels: ["1", "2", "3", "4"],
                                       trackingMode: .selectOne, target: self, action: #selector(depthChanged))
        depth.selectedSegment = min(max(state.scanDepth - 1, 0), 3)
        depth.segmentStyle = .texturedRounded
        let depthHint = label("Applies on the next scan. Higher = deeper project search.",
                              font: AAFont.caption(), color: AAColor.txMute)

        // Agents
        let agentsGrid = NSStackView()
        agentsGrid.orientation = .vertical
        agentsGrid.alignment = .leading
        agentsGrid.spacing = 4
        for agent in AgentCatalog.all where agent.key != "generic" {
            let cb = NSButton(checkboxWithTitle: agent.name, target: self, action: #selector(agentToggled(_:)))
            cb.state = state.enabledAgentKeys.contains(agent.key) ? .on : .off
            cb.identifier = NSUserInterfaceItemIdentifier(agent.key)
            agentsGrid.addArrangedSubview(cb)
        }

        let done = NSButton(title: "Done", target: self, action: #selector(closeSheet))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        let stack = NSStackView(views: [
            title,
            label("Accent", font: AAFont.sectionLabel(), color: AAColor.txMute), accentRow,
            label("Density", font: AAFont.sectionLabel(), color: AAColor.txMute), density,
            label("Scan depth", font: AAFont.sectionLabel(), color: AAColor.txMute), depth, depthHint,
            label("Agents to scan", font: AAFont.sectionLabel(), color: AAColor.txMute), agentsGrid,
            done,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(18, after: title)
        stack.setCustomSpacing(16, after: accentRow)
        stack.setCustomSpacing(16, after: density)
        stack.setCustomSpacing(16, after: depthHint)
        stack.setCustomSpacing(20, after: agentsGrid)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 360),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
        ])
        view = root
    }

    // MARK: Actions

    private func pickAccent(_ i: Int) {
        state.setAccent(i)
        for (idx, sw) in swatches.enumerated() { sw.setSelected(idx == i) }
    }
    @objc private func densityChanged(_ s: NSSegmentedControl) {
        state.setDensity(s.selectedSegment == 0 ? .compact : .comfortable)
    }
    @objc private func depthChanged(_ s: NSSegmentedControl) {
        state.setScanDepth(s.selectedSegment + 1)
    }
    @objc private func agentToggled(_ b: NSButton) {
        guard let key = b.identifier?.rawValue else { return }
        state.setAgentEnabled(key, b.state == .on)
    }
    @objc private func closeSheet() {
        dismiss(self)
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = font
        tf.textColor = color
        return tf
    }
}

/// A round color swatch for the accent picker.
final class SwatchView: NSView {
    var onClick: (() -> Void)?
    private let fill: NSColor

    init(color: NSColor, selected: Bool) {
        self.fill = color
        super.init(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.backgroundColor = color.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        setSelected(selected)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ on: Bool) {
        layer?.borderWidth = on ? 2.5 : 0
        layer?.borderColor = AAColor.tx.cgColor
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
}
