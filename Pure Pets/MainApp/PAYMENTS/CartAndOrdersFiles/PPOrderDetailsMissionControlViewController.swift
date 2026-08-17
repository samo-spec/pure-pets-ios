//
//  PPOrderDetailsMissionControlViewController.swift
//  Pure Pets
//

import SwiftUI
import UIKit

@available(iOS 17.0, *)
@MainActor
@objc(PPOrderDetailsMissionControlViewController)
final class PPOrderDetailsMissionControlViewController: UIViewController {
    private let bridge: PPOrderDetailsMissionControlBridge
    private let store: PPOrderDetailsMissionControlStore
    private var hostingController:
        UIHostingController<PPOrderDetailsMissionControlScreen>?
    private var inheritedNavigationBarHidden: Bool?
    private var inheritedInteractivePopEnabled: Bool?

    @objc(initWithOrder:)
    init(order: PPOrder) {
        let bridge = PPOrderDetailsMissionControlBridge(order: order)
        self.bridge = bridge
        store = PPOrderDetailsMissionControlStore(bridge: bridge)
        super.init(nibName: nil, bundle: nil)
        store.presenter = self
        store.onClose = { [weak self] in self?.closeMissionControl() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPOrderDetailsMissionControlViewController is code-only.")
    }

    private var isCheckoutOrigin: Bool = false

    @objc(configureEntryPresentationState:message:)
    func configureEntryPresentationState(
        _ state: Int,
        message: String?
    ) {
        if state == 1 || state == 2 {
            isCheckoutOrigin = true
        }
        store.configureEntryPresentation(state: state, message: message)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = Language.isRTL()
            ? .forceRightToLeft
            : .forceLeftToRight
        installSwiftUIHierarchy()
        store.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationOwnership(animated: animated)
        store.setCloseSymbol(closeSymbol)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        store.setVisible(true)
        store.presentEntryIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.setVisible(false)
        restoreNavigationOwnership(animated: animated)
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.userInterfaceStyle !=
            traitCollection.userInterfaceStyle {
            store.objectWillChange.send()
        }
    }

    private func installSwiftUIHierarchy() {
        let hosting = UIHostingController(
            rootView: PPOrderDetailsMissionControlScreen(store: store)
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

    private func configureNavigationOwnership(animated: Bool) {
        guard let navigationController else { return }
        if inheritedNavigationBarHidden == nil {
            inheritedNavigationBarHidden = navigationController.isNavigationBarHidden
        }
        navigationController.setNavigationBarHidden(true, animated: animated)
        if let gesture = navigationController.interactivePopGestureRecognizer {
            if inheritedInteractivePopEnabled == nil {
                inheritedInteractivePopEnabled = gesture.isEnabled
            }
            gesture.isEnabled = navigationController.viewControllers.count > 1
        }
    }

    private func restoreNavigationOwnership(animated: Bool) {
        guard let navigationController else { return }
        if let inheritedNavigationBarHidden {
            navigationController.setNavigationBarHidden(
                inheritedNavigationBarHidden,
                animated: animated
            )
            self.inheritedNavigationBarHidden = nil
        }
        if let gesture = navigationController.interactivePopGestureRecognizer,
           let inheritedInteractivePopEnabled {
            gesture.isEnabled = inheritedInteractivePopEnabled
            self.inheritedInteractivePopEnabled = nil
        }
    }

    private var isPaymentOrigin: Bool {
        if isCheckoutOrigin {
            return true
        }
        guard let navigationController,
              let index = navigationController.viewControllers.firstIndex(
                of: self
              ),
              index > 0,
              let paymentClass = NSClassFromString("PPSelectPaymentVC")
        else { return false }
        return navigationController.viewControllers[index - 1]
            .isKind(of: paymentClass)
    }

    private var isModalNavigationRoot: Bool {
        guard let navigationController else {
            return presentingViewController != nil
        }
        return navigationController.viewControllers.first === self &&
            navigationController.presentingViewController != nil
    }

    private var closeSymbol: String {
        if presentingViewController != nil || isModalNavigationRoot {
            return "xmark"
        }
        if isPaymentOrigin {
            return "house.fill"
        }
        return "chevron.backward"
    }

    private func closeMissionControl() {
        if isModalNavigationRoot {
            navigationController?.dismiss(animated: true)
            return
        }
        if presentingViewController != nil {
            dismiss(animated: true)
            return
        }
        if isPaymentOrigin {
            showHome(animated: true)
            return
        }
        navigationController?.popViewController(animated: true)
    }

    private func showHome(animated: Bool) {
        if let tabBarController,
           let homeController = tabBarController.viewControllers?.first {
            if let homeNavigation = homeController as? UINavigationController {
                let isCurrent = homeNavigation === navigationController
                homeNavigation.popToRootViewController(animated: isCurrent)
                tabBarController.selectedIndex = 0
                return
            }
            if homeController is PPHomeViewController {
                tabBarController.selectedIndex = 0
                return
            }
        }

        if let home = navigationController?.viewControllers.first(
            where: { $0 is PPHomeViewController }
        ) {
            navigationController?.popToViewController(home, animated: animated)
            return
        }
        if let navigationController {
            navigationController.popToRootViewController(animated: animated)
        } else {
            dismiss(animated: animated)
        }
    }
}

