//
//  ClickablePathField.swift
//  AgentAtlas
//
//  A path label that reveals its file in Finder on click (pointing-hand cursor).
//  Used in both the list row and the detail header.
//

import AppKit

@MainActor
final class ClickablePathField: NSTextField {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isBordered = false
        isSelectable = false
        drawsBackground = false
        lineBreakMode = .byTruncatingMiddle
        // never let a long path dictate the pane's minimum width
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

@MainActor
func revealInFinder(_ path: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
}
