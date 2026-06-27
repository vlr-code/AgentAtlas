//
//  MainToolbar.swift
//  AgentAtlas
//
//  Unified window toolbar (DESIGN_SYSTEM §5): axis switch · search · re-scan.
//  During a scan the re-scan button is replaced in place by a spinner.
//  Built in code (no storyboard), wired to AppState.
//

import AppKit

@MainActor
final class MainToolbarController: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {

    private let state: AppState
    private let axisControl = NSSegmentedControl()
    private let rescanButton = NSButton()
    private let spinner = NSProgressIndicator()

    private let axisID = NSToolbarItem.Identifier("axis")
    private let searchID = NSToolbarItem.Identifier("search")
    private let historyID = NSToolbarItem.Identifier("history")
    private let settingsID = NSToolbarItem.Identifier("settings")
    private let rescanID = NSToolbarItem.Identifier("rescan")

    init(state: AppState) {
        self.state = state
        super.init()
        state.observe { [weak self] in self?.syncScanning() }
    }

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "AgentAtlasToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [axisID, .flexibleSpace, searchID, historyID, settingsID, rescanID]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [axisID, searchID, historyID, settingsID, rescanID, .flexibleSpace, .space]
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch identifier {
        case axisID:
            axisControl.segmentStyle = .texturedRounded
            axisControl.trackingMode = .selectOne
            axisControl.segmentCount = AppState.Axis.allCases.count
            for (i, axis) in AppState.Axis.allCases.enumerated() {
                axisControl.setLabel(axis.rawValue, forSegment: i)
            }
            axisControl.selectedSegment = AppState.Axis.allCases.firstIndex(of: state.axis) ?? 0
            axisControl.target = self
            axisControl.action = #selector(axisChanged)
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.view = axisControl
            item.label = "View"
            item.visibilityPriority = .high
            return item

        case searchID:
            let item = NSSearchToolbarItem(itemIdentifier: identifier)
            item.searchField.delegate = self
            item.searchField.placeholderString = "Search name or path"
            return item

        case historyID:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Fix history")
            item.label = "History"
            item.toolTip = "Fix history & undo"
            item.isBordered = true
            item.target = self
            item.action = #selector(openHistory)
            return item

        case settingsID:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
            item.label = "Settings"
            item.toolTip = "Settings"
            item.isBordered = true
            item.target = self
            item.action = #selector(openSettings)
            return item

        case rescanID:
            rescanButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Re-scan")
            rescanButton.bezelStyle = .texturedRounded
            rescanButton.imagePosition = .imageOnly
            rescanButton.target = self
            rescanButton.action = #selector(rescan)
            rescanButton.translatesAutoresizingMaskIntoConstraints = false

            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isDisplayedWhenStopped = false
            spinner.isHidden = true
            spinner.translatesAutoresizingMaskIntoConstraints = false

            // Button and spinner share one slot — spinner replaces the button mid-scan.
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(rescanButton)
            container.addSubview(spinner)
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 36),
                container.heightAnchor.constraint(equalToConstant: 26),
                rescanButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                rescanButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])

            let item = NSToolbarItem(itemIdentifier: identifier)
            item.view = container
            item.label = "Re-scan"
            item.toolTip = "Re-scan"
            return item

        default:
            return nil
        }
    }

    @objc private func axisChanged() {
        state.axis = AppState.Axis.allCases[axisControl.selectedSegment]
    }

    @objc private func rescan() {
        state.startScan()
    }

    @objc private func openSettings() {
        guard let host = axisControl.window?.contentViewController else { return }
        host.presentAsSheet(SettingsViewController(state: state))
    }

    @objc private func openHistory() {
        guard let host = axisControl.window?.contentViewController else { return }
        host.presentAsSheet(FixHistoryViewController(state: state))
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField else { return }
        state.searchText = field.stringValue
    }

    private func syncScanning() {
        if state.phase == .scanning {
            rescanButton.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            rescanButton.isHidden = false
        }
    }
}
