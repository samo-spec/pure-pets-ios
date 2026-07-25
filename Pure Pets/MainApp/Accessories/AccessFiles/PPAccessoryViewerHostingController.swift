import SwiftUI
import UIKit

@available(iOS 16.0, *)
@objc(PPAccessoryViewerHostingController)
final class PPAccessoryViewerHostingController: UIViewController {
    private let contentController:
        UIHostingController<PPAccessoryViewerScreen>

    @objc(initWithAccessory:presenter:)
    init(accessory: PetAccessory?, presenter: UIViewController) {
        let store = PPAccessoryViewerStore(
            accessory: accessory,
            presenter: presenter
        )
        contentController = UIHostingController(
            rootView: PPAccessoryViewerScreen(store: store)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @objc
    required dynamic init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor =
            UIColor(named: "AppBageColor") ?? .systemGroupedBackground

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
}
