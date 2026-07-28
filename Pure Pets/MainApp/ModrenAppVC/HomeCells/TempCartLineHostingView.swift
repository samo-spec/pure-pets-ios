//
//  TempCartLineHostingView.swift
//  Pure Pets
//
//  Temporary hosting view for previewing AliveCartBar on real device
//

import SwiftUI
import UIKit

@available(iOS 17.0, *)
@objc(TempCartLineHostingView)
public final class TempCartLineHostingView: UIView {

    private var hostingController: UIHostingController<AliveCartBar>?
    private let controller: CartLineController

    public override init(frame: CGRect) {
        // Create a demo controller
        self.controller = CartLineController(
            quantity: 2,
            unitPrice: 150.0,
            maximumQuantity: 99,
            syncQuantity: { _ in
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        )
        super.init(frame: frame)
        setUpHostingController()
    }

    public required init?(coder: NSCoder) {
        self.controller = CartLineController(
            quantity: 2,
            unitPrice: 150.0,
            maximumQuantity: 99,
            syncQuantity: { _ in
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        )
        super.init(coder: coder)
        setUpHostingController()
    }

    private func setUpHostingController() {
        backgroundColor = .systemBlue // DEBUG
        isOpaque = true
        clipsToBounds = false
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false

        let copy = AliveCartCopy()
        let rootView = AliveCartBar(
            controller: controller,
            currencyCode: "QAR",
            copy: copy,
            onOpenCart: { print("Open cart tapped") }
        )
        let controller = UIHostingController(rootView: rootView)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.clipsToBounds = false
        controller.view.preservesSuperviewLayoutMargins = false
        controller.view.insetsLayoutMarginsFromSafeArea = false
        addSubview(controller.view)

        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        hostingController = controller
    }
}