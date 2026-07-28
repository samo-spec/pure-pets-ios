//
//  TempGlassRootTabHostingView.swift
//  Pure Pets
//
//  Temporary hosting view for previewing GlassRootTabView on real device
//

import SwiftUI
import UIKit

@available(iOS 17.0, *)
@objc(TempGlassRootTabHostingView)
public final class TempGlassRootTabHostingView: UIView {

    private var hostingController: UIHostingController<GlassRootTabView>?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpHostingController()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpHostingController()
    }

    private func setUpHostingController() {
        backgroundColor = .systemRed // DEBUG
        isOpaque = true
        clipsToBounds = false
        preservesSuperviewLayoutMargins = false
        insetsLayoutMarginsFromSafeArea = false

        let rootView = GlassRootTabView()
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