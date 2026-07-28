import SwiftUI
import UIKit

@objc public protocol ServiceViewerDelegate: AnyObject {
    @objc optional func serviceViewer(_ viewer: ServiceViewerViewController, didContactServiceProvider service: ServiceModel)
    @objc optional func serviceViewerDidFavoriteService(_ viewer: ServiceViewerViewController)
}

@objc(ServiceViewerViewController)
public class ServiceViewerViewController: UIViewController {
    @objc public weak var delegate: ServiceViewerDelegate?

    private let store = PPServiceViewerStore()
    private var hostingController: UIViewController?

    @objc public var service: ServiceModel? {
        didSet {
            if let service {
                store.configure(with: service)
            }
        }
    }

    @objc public init(service: ServiceModel? = nil) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
        if let service {
            store.configure(with: service)
        }
    }

    @objc override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @objc required dynamic public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        if #available(iOS 16.0, *) {
            let screen = PPServiceViewerScreen(store: store, onClose: { [weak self] in
                guard let self else { return }
                if let nav = self.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            })

            let host = UIHostingController(rootView: screen)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(host)
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            host.didMove(toParent: self)
            self.hostingController = host
        }
    }
}
