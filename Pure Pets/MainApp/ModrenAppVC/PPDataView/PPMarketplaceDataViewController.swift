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
final class PPMarketplaceDataViewController: UIViewController, UIGestureRecognizerDelegate {
    private let bridge: PPMarketplaceDataViewBridge
    private let store: PPMarketplaceDataViewStore
    private var hostingController: UIHostingController<PPMarketplaceDataViewScreen>?
    private var inheritedNavigationBarHidden: Bool?
    private lazy var backEdgeGesture: UIScreenEdgePanGestureRecognizer = {
        let gesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleBackEdgeGesture(_:))
        )
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = self
        return gesture
    }()

    @objc(initWithInput:)
    init(input: PPDataViewInput) {
        let bridge = PPMarketplaceDataViewBridge(input: input)
        self.bridge = bridge
        store = PPMarketplaceDataViewStore(bridge: bridge)
        super.init(nibName: nil, bundle: nil)
        bridge.presentingViewController = self
        hidesBottomBarWhenPushed = true
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PPMarketplaceDataViewController is code-only.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.semanticContentAttribute = PPUniversalCellSwiftUIBridge.isRightToLeft()
            ? .forceRightToLeft
            : .forceLeftToRight
        configureNavigationAppearance()
        installSwiftUIHierarchy()
        view.addGestureRecognizer(backEdgeGesture)
        store.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController {
            inheritedNavigationBarHidden = navigationController.isNavigationBarHidden
            navigationController.setNavigationBarHidden(true, animated: animated)
        }
        configureBackNavigation()
        bridge.screenWillAppear()
        store.schedulePresentationStateRefresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureBackNavigation()
        PPRootLegacyAdapter.applySurface(for: self, animated: animated)
        store.schedulePresentationStateRefresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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

    override func accessibilityPerformEscape() -> Bool {
        guard canNavigateBack else {
            return super.accessibilityPerformEscape()
        }
        bridge.goBack()
        return true
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

    private func configureBackNavigation() {
        guard let navigationController,
              navigationController.topViewController === self else { return }

        // UIKit resolves its leading edge and transition direction from the
        // navigation container, independently of SwiftUI's layout direction.
        let semantic = PPUniversalCellSwiftUIBridge.isRightToLeft()
            ? UISemanticContentAttribute.forceRightToLeft
            : .forceLeftToRight
        navigationController.view.semanticContentAttribute = semantic
        navigationController.navigationBar.semanticContentAttribute = semantic
        backEdgeGesture.edges = semantic == .forceRightToLeft ? .right : .left

        // The hidden navigation bar's system gesture is unreliable on this host.
        // Keep ownership local and route a completed edge swipe through the same
        // back action as the visible control, without replacing the nav delegate.
        navigationController.pp_enableInteractivePopGesture()
    }

    @objc(pp_disableInteractivePopGesture)
    func pp_disableInteractivePopGesture() -> Bool {
        // Prevent two recognizers from popping the same screen.
        true
    }

    private var canNavigateBack: Bool {
        guard let navigationController else { return false }
        return navigationController.topViewController === self
            && navigationController.viewControllers.count > 1
            && navigationController.transitionCoordinator == nil
            && presentedViewController == nil
            && !isBeingDismissed
            && !isMovingFromParent
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === backEdgeGesture, canNavigateBack else { return false }
        let velocity = backEdgeGesture.velocity(in: view)
        let inwardVelocity = backEdgeGesture.edges == .right ? -velocity.x : velocity.x
        return inwardVelocity > abs(velocity.y)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // SwiftUI also installs non-UIPan recognizers for its drag gestures.
        // Give the edge priority over those as well as the scroll view's pan.
        gestureRecognizer === backEdgeGesture
            && otherGestureRecognizer !== navigationController?.interactivePopGestureRecognizer
    }

    @objc private func handleBackEdgeGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, canNavigateBack else { return }
        let direction: CGFloat = gesture.edges == .right ? -1 : 1
        let distance = gesture.translation(in: view).x * direction
        let velocity = gesture.velocity(in: view).x * direction
        let crossedThreshold = distance >= max(44, view.bounds.width * 0.16)
        let deliberateFlick = distance >= 16 && velocity >= 650
        guard velocity >= 0, crossedThreshold || deliberateFlick else { return }
        bridge.goBack()
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
