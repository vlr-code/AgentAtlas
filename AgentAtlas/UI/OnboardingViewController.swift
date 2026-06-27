//
//  OnboardingViewController.swift
//  AgentAtlas
//
//  Full-window first-run screen: agent icon strip, title, one-line pitch,
//  and a gold "Scan now" CTA. Shown until the first scan starts.
//

import AppKit

final class OnboardingViewController: NSViewController {

    private let state: AppState

    init(state: AppState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = AAColor.winBg.cgColor

        // Supported-agent icon strip (shows the breadth of coverage)
        let iconRow = NSStackView()
        iconRow.orientation = .horizontal
        iconRow.spacing = 10
        iconRow.translatesAutoresizingMaskIntoConstraints = false
        for key in ["claude", "cursor", "windsurf", "cline", "codex", "gemini", "continue", "qwen"] {
            guard let img = NSImage(named: key) else { continue }
            let iv = NSImageView()
            iv.image = roundedImage(img, side: 34, radius: 8)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 34).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 34).isActive = true
            iconRow.addArrangedSubview(iv)
        }

        let title = NSTextField(labelWithString: "AgentAtlas")
        title.font = .systemFont(ofSize: 34, weight: .semibold)
        title.textColor = AAColor.tx
        title.alignment = .center

        let subtitle = NSTextField(wrappingLabelWithString:
            "Every AI-agent config on your Mac, in one map — rules, MCP servers, skills, commands, subagents and settings, across all your tools.")
        subtitle.font = AAFont.body(13.5)
        subtitle.textColor = AAColor.txDim
        subtitle.alignment = .center
        subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 470).isActive = true

        let button = NSButton(title: "Scan now", target: self, action: #selector(scanNow))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        button.bezelColor = AAColor.accent
        button.contentTintColor = AAColor.winBg

        let hint = NSTextField(labelWithString: "Scans ~/.claude, ~/.cursor, ~/.codeium … and your project folders")
        hint.font = AAFont.caption()
        hint.textColor = AAColor.txMute
        hint.alignment = .center

        let stack = NSStackView(views: [iconRow, title, subtitle, button, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.setCustomSpacing(24, after: iconRow)
        stack.setCustomSpacing(22, after: subtitle)
        stack.setCustomSpacing(26, after: button)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -40),
        ])
        view = root
    }

    @objc private func scanNow() {
        state.startScan()
    }
}
