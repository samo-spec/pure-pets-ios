//
//  AdoptPetsHostingControllers.swift
//  Pure Pets
//
//  UIKit Hosting Controllers wrapping Adopt Pet SwiftUI List and Details screens.
//  Exposed to Objective-C with canonical `@objc(AdoptPetsViewController)` and
//  `@objc(AdoptPetDetailsViewController)` names to replace legacy view controllers.
//

import SwiftUI
import UIKit

// MARK: - AdoptPetsViewController (List)

@objc(AdoptPetsViewController)
final class AdoptPetsViewController: UIViewController {
    private var hostingController: UIHostingController<AdoptPetListScreen>?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let listScreen = AdoptPetListScreen(
            onSelectPet: { [weak self] pet in
                self?.openDetails(for: pet)
            },
            onAddPet: { [weak self] in
                self?.openAddPetForm()
            },
            onClose: { [weak self] in
                self?.handleClose()
            }
        )

        let hc = UIHostingController(rootView: listScreen)
        self.hostingController = hc

        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        view.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hc.didMove(toParent: self)
    }

    private var previousNavigationBarHidden = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !previousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func openDetails(for pet: AdoptPetModel) {
        let detailsVC = AdoptPetDetailsViewController(model: pet)
        if let nav = navigationController {
            nav.pushViewController(detailsVC, animated: true)
        } else {
            detailsVC.modalPresentationStyle = .pageSheet
            present(detailsVC, animated: true)
        }
    }

    private func openAddPetForm() {
        guard UserManager.shared().isUserLoggedIn() else {
            UserManager.showPromptOnTopController()
            return
        }

        let addVC = AddAdoptPetViewController()
        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    private func handleClose() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - AdoptPetDetailsViewController (Details)

@objc(AdoptPetDetailsViewController)
final class AdoptPetDetailsViewController: UIViewController {
    private var hostingController: UIHostingController<AdoptPetDetailsScreen>?
    private let petModel: AdoptPetModel?
    private let isOwner: Bool
    private var previousNavigationBarHidden = false

    @objc(initWithModel:)
    init(model: AdoptPetModel?) {
        self.petModel = model
        let currentUID = UserManager.shared().currentUser?.id ?? ""
        self.isOwner = {
            guard let model else { return false }
            return !model.ownerID.isEmpty && model.ownerID == currentUID
        }()
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    @objc(initWithModel:isOwner:)
    init(model: AdoptPetModel?, isOwner: Bool) {
        self.petModel = model
        self.isOwner = isOwner
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        self.petModel = nil
        self.isOwner = false
        super.init(coder: coder)
        self.hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        guard let model = petModel else {
            showEmptyFallback()
            return
        }

        weak var weakSelf = self
        let detailsScreen = AdoptPetDetailsScreen(
            pet: model,
            isOwner: isOwner,
            hostViewControllerProvider: {
                return weakSelf
            }
        )

        let hc = UIHostingController(rootView: detailsScreen)
        self.hostingController = hc

        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        view.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hc.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !previousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func showEmptyFallback() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = PPAdoptLang("adopt_list_error_title")
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle(PPAdoptLang("Close"), for: .normal)
        closeBtn.addTarget(self, action: #selector(handleCloseFallback), for: .touchUpInside)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(closeBtn)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func handleCloseFallback() {
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
