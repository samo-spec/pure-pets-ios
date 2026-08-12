//
//  PPOrderHistorySurfaceController.swift
//  Pure Pets
//

import SwiftUI
import UIKit

@available(iOS 17.0, *)
@MainActor
@objc(PPOrderHistorySurfaceController)
final class PPOrderHistorySurfaceController: UIViewController {
    private let store = PPOrderHistorySurfaceStore()
    private var hostingController: UIHostingController<PPOrderHistoryScreen>?

    @objc(initWithDelegate:)
    init(delegate: PPOrderHistorySurfaceControllerDelegate) {
        super.init(nibName: nil, bundle: nil)
        store.delegate = delegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPOrderHistorySurfaceController is code-only.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = Language.isRTL()
            ? .forceRightToLeft
            : .forceLeftToRight

        let hosting = UIHostingController(
            rootView: PPOrderHistoryScreen(store: store)
        )
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    @objc(applySnapshot:)
    func applySnapshot(_ descriptor: PPOrderHistorySnapshotDescriptor) {
        store.apply(descriptor)
    }
}
