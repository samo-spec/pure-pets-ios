//
//  AddAdoptPetHostingController.swift
//  Pure Pets
//
//  UIKit Hosting Controller wrapping the AddAdoptPetScreen SwiftUI root view.
//  Exposed to Objective-C as `@objc(AddAdoptPetHostingController)` for seamless
//  integration across the Pure Pets ecosystem.
//

import SwiftUI
import UIKit

@objc(AddAdoptPetHostingController)
public final class AddAdoptPetHostingController: UIViewController {
    private var hostingController: UIHostingController<AddAdoptPetScreen>?
    private let editingPet: AdoptPetModel?
    private var onDismissCallback: (() -> Void)?
    private var onSuccessCallback: (() -> Void)?
    private var previousNavigationBarHidden = false

    @objc(initWithPet:)
    public init(pet: AdoptPetModel?) {
        self.editingPet = pet
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.hidesBottomBarWhenPushed = true
    }

    @objc(initWithPet:onDismiss:onSuccess:)
    public init(pet: AdoptPetModel?, onDismiss: (() -> Void)?, onSuccess: (() -> Void)?) {
        self.editingPet = pet
        self.onDismissCallback = onDismiss
        self.onSuccessCallback = onSuccess
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        self.modalPresentationStyle = .fullScreen
        if let nav = navigationController {
            nav.modalPresentationStyle = .fullScreen
        }

        let screen = AddAdoptPetScreen(
            pet: editingPet,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSuccess: { [weak self] in
                self?.handleSuccess()
            }
        )

        let hc = UIHostingController(rootView: screen)
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

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !previousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func handleDismiss() {
        if let callback = onDismissCallback {
            callback()
            return
        }
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func handleSuccess() {
        if let callback = onSuccessCallback {
            callback()
            return
        }
        if let nav = navigationController, nav.viewControllers.first != self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
