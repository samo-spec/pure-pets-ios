import SwiftUI
import UIKit

@objc public protocol ServiceViewerDelegate: AnyObject {
    @objc optional func serviceViewer(_ viewer: ServiceViewerViewController, didContactServiceProvider service: ServiceModel)
    @objc optional func serviceViewerDidFavoriteService(_ viewer: ServiceViewerViewController)
}

@MainActor
@objc(ServiceViewerViewController)
public class ServiceViewerViewController: UIViewController {
    @objc public weak var delegate: ServiceViewerDelegate?
    private let store = PPServiceViewerStore()
    private var hostingController: UIViewController?
    private var previousNavigationBarHidden: Bool?
    private var isPresentingSignIn = false

    @objc public var service: ServiceModel? {
        didSet {
            if let service { store.configure(with: service) }
        }
    }

    @objc public init(service: ServiceModel? = nil) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
        if let service { store.configure(with: service) }
    }

    @objc override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @objc required dynamic public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if previousNavigationBarHidden == nil {
            previousNavigationBarHidden = navigationController?.isNavigationBarHidden
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
        view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let previousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(previousNavigationBarHidden, animated: animated)
        }
        previousNavigationBarHidden = nil
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        store.presentingViewController = self
        store.onRequestSignIn = { [weak self] in self?.presentSignIn() }
        store.onContactOpened = { [weak self] in
            guard let self, let service = self.store.service else { return }
            self.delegate?.serviceViewer?(self, didContactServiceProvider: service)
        }

        if #available(iOS 15.0, *) {
            let screen = PPServiceViewerScreen(store: store, onClose: { [weak self] in self?.close() })
            let host = UIHostingController(rootView: screen)
            host.view.backgroundColor = .ppBackground
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
            hostingController = host
        }
    }

    private func close() {
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: !UIAccessibility.isReduceMotionEnabled)
        } else {
            (navigationController ?? self).dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }

    private func presentSignIn() {
        guard !isPresentingSignIn else { return }
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            guard !presented.isBeingDismissed else { return }
            presenter = presented
        }
        guard presenter.viewIfLoaded?.window != nil else { return }
        isPresentingSignIn = true
        // Existing sign-in owner creates/synchronizes the profile. Success only
        // refreshes read state; a review/contact draft is never submitted for the user.
        PPUserSigningManager.presentSignIn(from: presenter, success: { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isPresentingSignIn = false
                if self.viewIfLoaded?.window != nil { self.store.refresh() }
            }
        }, failure: { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.isPresentingSignIn = false
                self?.store.bannerMessage = PPServiceViewerL10n.text("service_note_sign_in_failed")
            }
        }, cancelled: { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.isPresentingSignIn = false }
        })
    }
}
