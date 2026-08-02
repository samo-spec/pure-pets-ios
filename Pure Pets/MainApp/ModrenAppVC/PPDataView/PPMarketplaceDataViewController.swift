import SwiftUI
import UIKit

/// Runtime owner for the independent SwiftUI marketplace DataViewer.
///
/// The controller intentionally exposes the bottom-surface selectors used by
/// the existing root coordinator. Its visible hierarchy is entirely SwiftUI;
/// backend and action behavior is forwarded through
/// `PPMarketplaceDataViewBridge`.
@available(iOS 15.0, *)
@MainActor
@objc(PPMarketplaceDataViewController)
final class PPMarketplaceDataViewController: UIViewController {
    private let bridge: PPMarketplaceDataViewBridge
    private let store: PPMarketplaceDataViewStore
    private var hostingController: UIHostingController<PPMarketplaceDataViewScreen>?
    private var inheritedNavigationBarHidden: Bool?
    private var inheritedInteractivePopGestureEnabled: Bool?

    @objc(initWithInput:)
    init(input: PPDataViewInput) {
        let bridge = PPMarketplaceDataViewBridge(input: input)
        self.bridge = bridge
        store = PPMarketplaceDataViewStore(bridge: bridge)
        super.init(nibName: nil, bundle: nil)
        bridge.presentingViewController = self
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPMarketplaceDataViewController is code-only.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = PPUniversalCellSwiftUIBridge.isRightToLeft()
            ? .forceRightToLeft
            : .forceLeftToRight
        configureNavigationAppearance()
        installSwiftUIHierarchy()
        store.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController {
            inheritedNavigationBarHidden = navigationController.isNavigationBarHidden
            navigationController.setNavigationBarHidden(true, animated: animated)
        }
        if let interactivePopGestureRecognizer =
            navigationController?.interactivePopGestureRecognizer {
            inheritedInteractivePopGestureEnabled =
                interactivePopGestureRecognizer.isEnabled
            interactivePopGestureRecognizer.isEnabled = true
        }
        bridge.screenWillAppear()
        store.schedulePresentationStateRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let interactivePopGestureRecognizer =
                navigationController?.interactivePopGestureRecognizer,
           let inheritedInteractivePopGestureEnabled {
            interactivePopGestureRecognizer.isEnabled =
                inheritedInteractivePopGestureEnabled
            self.inheritedInteractivePopGestureEnabled = nil
        }
        if let navigationController,
           let inheritedNavigationBarHidden {
            navigationController.setNavigationBarHidden(
                inheritedNavigationBarHidden,
                animated: animated
            )
            self.inheritedNavigationBarHidden = nil
        }
        bridge.screenWillDisappear()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        store.schedulePresentationStateRefresh()
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory
            || previousTraitCollection?.userInterfaceStyle
            != traitCollection.userInterfaceStyle {
            store.schedulePresentationStateRefresh()
        }
    }

    @objc(sectionFromDeepLinkTarget:)
    func section(from target: PPDeepLinkTarget) -> PPDataSection {
        let rawSection: Int
        switch target.rawValue {
        case 2:
            rawSection = 1
        case 3:
            rawSection = 2
        case 5, 6, 7, 8:
            rawSection = 3
        default:
            rawSection = 0
        }
        return PPDataSection(rawValue: rawSection)!
    }

    // MARK: Root bottom-surface runtime contract

    /// `PPBottomSurfaceKindFloatingCartSurface` has raw value 3. Returning
    /// NSInteger keeps this Swift class independent of a private ObjC enum
    /// import while preserving the exact Objective-C selector ABI.
    @objc(pp_preferredBottomSurfaceKind)
    func pp_preferredBottomSurfaceKind() -> Int {
        3
    }

    @objc(pp_isFloatingCartEligible)
    func pp_isFloatingCartEligible() -> Bool {
        true
    }

    @objc(pp_openCart)
    func pp_openCart() {
        store.openCart()
    }

    @objc(updateCollectionContentInset)
    func updateCollectionContentInset() {
        store.schedulePresentationStateRefresh()
    }

    @objc(pp_updateBottomNavigationInsetsIfNeeded)
    func pp_updateBottomNavigationInsetsIfNeeded() {
        store.schedulePresentationStateRefresh()
    }

    private func installSwiftUIHierarchy() {
        let hosting = UIHostingController(
            rootView: PPMarketplaceDataViewScreen(store: store)
        )
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        let topConstraint = hosting.view.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: 0
        )
        topConstraint.identifier = "pp.marketplace.hosting.top-to-view"
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topConstraint,
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    private func configureNavigationAppearance() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.title = ""

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }
}
