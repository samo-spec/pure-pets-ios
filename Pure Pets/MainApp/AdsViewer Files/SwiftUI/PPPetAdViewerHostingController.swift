import SwiftUI
import UIKit

@available(iOS 16.0, *)
@objc(PPPetAdViewerHostingController)
final class PPPetAdViewerHostingController: UIViewController {
    private let hostActions: PPPetAdViewerHostActions
    private let contentController:
        UIHostingController<PPPetAdViewerNavigationRoot>
    private weak var containingNavigationController:
        UINavigationController?
    private var previousNavigationBarHidden: Bool?
    private var previousNavigationBarStyle: UIBarStyle?
    private var shouldRestoreChrome = false

    @objc(initWithAd:)
    init(ad: PetAd) {
        let actions = PPPetAdViewerHostActions()
        let repository = PPLegacyPetAdViewerRepository()
        hostActions = actions
        contentController = UIHostingController(
            rootView: PPPetAdViewerNavigationRoot(
                ad: ad,
                repository: repository,
                hostActions: actions
            )
        )
        if #available(iOS 16.4, *) {
            contentController.safeAreaRegions = []
        }

        super.init(nibName: nil, bundle: nil)

        actions.presenter = self
        modalPresentationStyle = .fullScreen
        hidesBottomBarWhenPushed = true
    }

    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor =
            UIColor(named: "AppBackgroundColor") ?? .systemBackground
        navigationItem.largeTitleDisplayMode = .never

        // Keep status bar dark during load transition by setting barStyle to default early
        navigationController?.navigationBar.barStyle = .default

        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints =
            false
        contentController.view.backgroundColor = .clear
        view.addSubview(contentController.view)
        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            contentController.view.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            contentController.view.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            contentController.view.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
        contentController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        containingNavigationController = navigationController
        if previousNavigationBarHidden == nil {
            previousNavigationBarHidden =
                navigationController?.isNavigationBarHidden
        }
        if previousNavigationBarStyle == nil {
            previousNavigationBarStyle =
                navigationController?.navigationBar.barStyle
        }
        navigationController?.setNavigationBarHidden(
            true,
            animated: animated
        )
        applyViewerStatusBarAppearance()
        navigationController?.interactivePopGestureRecognizer?.isEnabled =
            true
        PPPetAdViewerLegacyBridge.setPremiumTabDockHidden(
            true,
            animated: animated,
            from: self
        )
        shouldRestoreChrome = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PPPetAdViewerLegacyBridge.setPremiumTabDockHidden(
            true,
            animated: false,
            from: self
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        shouldRestoreChrome =
            isMovingFromParent ||
            isBeingDismissed ||
            navigationController?.isBeingDismissed == true
        guard shouldRestoreChrome else { return }

        if let previousNavigationBarHidden {
            containingNavigationController?.setNavigationBarHidden(
                previousNavigationBarHidden,
                animated: animated
            )
        }
        if let previousNavigationBarStyle {
            containingNavigationController?.navigationBar.barStyle =
                previousNavigationBarStyle
            containingNavigationController?
                .setNeedsStatusBarAppearanceUpdate()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard shouldRestoreChrome else { return }

        PPPetAdViewerLegacyBridge.setPremiumTabDockHidden(
            false,
            animated: false,
            from: containingNavigationController ?? self
        )
    }

    override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle
                != traitCollection.userInterfaceStyle else {
            return
        }
        applyViewerStatusBarAppearance()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }

    private func applyViewerStatusBarAppearance() {
        navigationController?.navigationBar.barStyle = .default
        navigationController?.setNeedsStatusBarAppearanceUpdate()
        setNeedsStatusBarAppearanceUpdate()
    }
}
