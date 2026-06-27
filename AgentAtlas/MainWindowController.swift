//
//  MainWindowController.swift
//  AgentAtlas
//
//  Builds the main window in code and hosts the three-pane map.
//

import Cocoa

final class MainWindowController: NSWindowController {

    let state: AppState
    private let toolbarController: MainToolbarController

    init(state: AppState) {
        self.state = state
        self.toolbarController = MainToolbarController(state: state)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentAtlas"
        window.minSize = NSSize(width: 900, height: 560)
        // MVP is dark-only (see DESIGN_SYSTEM.md §1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentViewController = RootContainerViewController(state: state)
        window.toolbar = toolbarController.makeToolbar()
        window.toolbarStyle = .unified
        window.center()

        super.init(window: window)
        window.setFrameAutosaveName("AgentAtlasMainWindow")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
