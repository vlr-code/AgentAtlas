//
//  RowComponents.swift
//  AgentAtlas
//
//  Small reusable views for the artifact row & detail header: agent monogram,
//  scope pill, format tag, flag cluster, category/flag icons. Icons use SF
//  Symbols (native stroke style) as a stand-in for the design's SVG set;
//  swapping in UI/design-system/icons/ is a later polish step.
//

import AppKit

// MARK: - Icon helpers

@MainActor
func aaSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular, tint: NSColor) -> NSImageView {
    let iv = NSImageView()
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    iv.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
    iv.contentTintColor = tint
    iv.translatesAutoresizingMaskIntoConstraints = false
    iv.setContentHuggingPriority(.required, for: .horizontal)
    return iv
}

@MainActor
func categorySymbolName(_ c: Category) -> String {
    switch c {
    case .rules:     return "doc.text"
    case .mcp:       return "server.rack"
    case .skills:    return "wand.and.stars"
    case .commands:  return "terminal"
    case .subagents: return "person.2"
    case .settings:  return "gearshape"
    }
}

@MainActor
func flagSymbolName(_ f: Flag) -> String {
    switch f {
    case .conflict:   return "exclamationmark.triangle.fill"
    case .duplicate:  return "square.on.square"
    case .symlink:    return "link"
    case .parseError: return "xmark.circle.fill"
    case .disabled:   return "minus.circle.fill"
    case .overrides:  return "arrow.up.circle.fill"
    }
}

// MARK: - Scope pill

@MainActor
final class ScopePillView: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        translatesAutoresizingMaskIntoConstraints = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AAFont.caption()
        addSubview(icon)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 18),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 10),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 3),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(scope: Scope) {
        let cfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        if scope.isGlobal {
            icon.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
            icon.contentTintColor = AAColor.txDim
            label.stringValue = "Global"
            label.textColor = AAColor.txDim
            layer?.backgroundColor = AAColor.s2.cgColor
        } else {
            icon.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
            icon.contentTintColor = AAColor.acTx
            label.stringValue = scope.label
            label.textColor = AAColor.acTx
            layer?.backgroundColor = AAColor.ac12.cgColor
        }
    }
}

// MARK: - Format tag (MD / JSON / YAML / TOML)

@MainActor
final class FormatTagView: NSView {
    private let label = NSTextField(labelWithString: "")
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.backgroundColor = AAColor.s1.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        label.font = AAFont.mono(9.5, weight: .medium)
        label.textColor = AAColor.txMute
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(format: FileFormat) { label.stringValue = format.tag }
}

// MARK: - Flag cluster

@MainActor
final class FlagClusterView: NSStackView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .horizontal
        spacing = 5
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(flags: Set<Flag>, broken: Bool) {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        // stable order
        let order: [Flag] = [.conflict, .overrides, .duplicate, .symlink, .parseError, .disabled]
        for flag in order where flags.contains(flag) {
            let color = broken && flag == .symlink ? AAColor.danger : flag.color
            let iv = aaSymbol(flagSymbolName(flag), pointSize: 11, weight: .medium, tint: color)
            iv.toolTip = flag.label
            addArrangedSubview(iv)
        }
    }
}
