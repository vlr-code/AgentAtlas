//
//  RootContainerViewController.swift
//  AgentAtlas
//
//  Swaps the whole window between the full-screen onboarding and the map,
//  driven by scan phase. Also hides the toolbar while onboarding is up.
//

import AppKit

final class RootContainerViewController: NSViewController {

    private let state: AppState
    private let onboarding: OnboardingViewController
    let split: RootSplitViewController

    init(state: AppState) {
        self.state = state
        self.onboarding = OnboardingViewController(state: state)
        self.split = RootSplitViewController(state: state)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(onboarding)
        addChild(split)
        for child in [onboarding.view, split.view] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
            NSLayoutConstraint.activate([
                child.topAnchor.constraint(equalTo: view.topAnchor),
                child.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }
        state.observe { [weak self] in self?.update() }
        update()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        update()
    }

    private func update() {
        let idle = state.phase == .idle
        onboarding.view.isHidden = !idle
        split.view.isHidden = idle
        view.window?.toolbar?.isVisible = !idle
    }
}
