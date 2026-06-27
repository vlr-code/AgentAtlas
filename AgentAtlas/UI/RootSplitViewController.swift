//
//  RootSplitViewController.swift
//  AgentAtlas
//
//  The three-pane map: sidebar (axis tree) · list (artifacts) · detail.
//  Mirrors the SwiftUI NavigationSplitView from the design on AppKit.
//

import AppKit

final class RootSplitViewController: NSSplitViewController {

    let state: AppState
    let sidebar: SidebarViewController
    let list: ListViewController
    let detail: DetailViewController

    init(state: AppState) {
        self.state = state
        self.sidebar = SidebarViewController(state: state)
        self.list = ListViewController(state: state)
        self.detail = DetailViewController(state: state)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 208
        sidebarItem.maximumThickness = 340
        sidebarItem.canCollapse = false

        let listItem = NSSplitViewItem(contentListWithViewController: list)
        listItem.minimumThickness = 340

        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.minimumThickness = 300
        detailItem.canCollapse = false

        addSplitViewItem(sidebarItem)
        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)
    }
}
