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
    private var hostingController: UIHostingController<AnyView>?
    private let editingPet: AdoptPetModel?
    private var onDismissCallback: (() -> Void)?
    private var onSuccessCallback: (() -> Void)?
    private var previousNavigationBarHidden = false

    public override var modalPresentationStyle: UIModalPresentationStyle {
        get { .fullScreen }
        set { super.modalPresentationStyle = .fullScreen }
    }

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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        self.modalPresentationStyle = .fullScreen
        if let nav = navigationController {
            nav.modalPresentationStyle = .fullScreen
        }

        applyCurrentLanguageDirection()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageDidChange),
            name: NSNotification.Name("LanguageDidChangeNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageDidChange),
            name: NSNotification.Name("PPLanguageDidChangeNotification"),
            object: nil
        )

        let isRTL = Language.isRTL()
        let screen = AddAdoptPetScreen(
            pet: editingPet,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSuccess: { [weak self] in
                self?.handleSuccess()
            }
        )

        let directionalRoot = AnyView(
            screen
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: isRTL ? "ar" : "en"))
        )

        let hc = UIHostingController(rootView: directionalRoot)
        self.hostingController = hc

        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        hc.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        view.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hc.didMove(toParent: self)
        setupKeyboardDismissTap()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyCurrentLanguageDirection()
        previousNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func applyCurrentLanguageDirection() {
        let attr = Language.semanticAttributeForCurrentLanguage()
        view.semanticContentAttribute = attr
        navigationController?.view.semanticContentAttribute = attr
        navigationController?.navigationBar.semanticContentAttribute = attr
        hostingController?.view.semanticContentAttribute = attr
    }

    @objc private func handleLanguageDidChange() {
        applyCurrentLanguageDirection()
        if let editingPet {
            rebuildHostingController(for: editingPet)
        } else {
            rebuildHostingController(for: nil)
        }
    }

    private func rebuildHostingController(for pet: AdoptPetModel?) {
        let isRTL = Language.isRTL()
        let screen = AddAdoptPetScreen(
            pet: pet,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSuccess: { [weak self] in
                self?.handleSuccess()
            }
        )
        let directionalRoot = AnyView(
            screen
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: isRTL ? "ar" : "en"))
        )
        hostingController?.rootView = directionalRoot
        hostingController?.view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        view.setNeedsLayout()
        view.layoutIfNeeded()
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

// MARK: - Keyboard Dismiss On Tap Outside

extension AddAdoptPetHostingController: UIGestureRecognizerDelegate {
    private func setupKeyboardDismissTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTapDismiss))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTapDismiss() {
        view.endEditing(true)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var targetView: UIView? = touch.view
        while let current = targetView {
            if current is UITextField || current is UITextView {
                return false
            }
            targetView = current.superview
        }
        return true
    }
}
