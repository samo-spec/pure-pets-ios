import SwiftUI
import UIKit

@objc(PPPetAdViewerHostingController)
final class PPPetAdViewerHostingController: UIViewController {
    private let hostActions: PPPetAdViewerHostActions
    private let contentController:
        UIHostingController<PPPetAdViewerNavigationRoot>
    private weak var containingNavigationController:
        UINavigationController?
    private var previousNavigationBarHidden: Bool?
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
        navigationController?.setNavigationBarHidden(
            true,
            animated: animated
        )
        navigationController?.interactivePopGestureRecognizer?.isEnabled =
            true
        PPPetAdViewerLegacyBridge.setPremiumTabDockHidden(
            true,
            animated: animated,
            from: self
        )
        shouldRestoreChrome = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let previousNavigationBarHidden {
            containingNavigationController?.setNavigationBarHidden(
                previousNavigationBarHidden,
                animated: animated
            )
        }
        shouldRestoreChrome =
            isMovingFromParent ||
            isBeingDismissed ||
            navigationController?.isBeingDismissed == true
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

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}
