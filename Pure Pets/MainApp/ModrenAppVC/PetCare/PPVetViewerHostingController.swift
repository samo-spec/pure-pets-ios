//
//  PPVetViewerHostingController.swift
//  Pure Pets
//
//  Reinvented from absolute first principles for NextGen V6 Flagship.
//  Hosting controller bridging PPVetViewerScreen into Objective-C / UIKit navigation.
//

import Combine
import SwiftUI
import UIKit

// MARK: - Presentation Content
@objc(PPVetViewerContent)
@objcMembers
final class PPVetViewerContent: NSObject {
    var vetID: String = ""
    var title: String = ""
    var isCompany: Bool = false
    var logoURL: String = ""
    var descriptionText: String = ""
    var phone: String = ""
    var whatsapp: String = ""
    var vetCost: Double = 0.0
    var readyToContact: Bool = false
    var verificationStatus: String = ""
    var subscriptionActive: Bool = false
    var subscriptionTier: Int = 0
    var availableDateText: String = ""
    var animalTypes: [String] = []
    var mainKindName: String = ""
}

// MARK: - Presentation State
@MainActor
final class PPVetViewerPresentation: ObservableObject {
    @Published private(set) var snapshot: PPVetViewerSnapshot

    init(content: PPVetViewerContent) {
        self.snapshot = PPVetViewerSnapshot(content: content)
    }

    func update(content: PPVetViewerContent) {
        let next = PPVetViewerSnapshot(content: content)
        guard next != snapshot else { return }
        snapshot = next
    }
}

// MARK: - Hosting Controller
@MainActor
@objc(PPVetViewerHostingController)
final class PPVetViewerHostingController: UIViewController {
    private let presentation: PPVetViewerPresentation
    private let contentController: UIHostingController<PPVetViewerScreen>

    @objc(initWithContent:onCall:onWhatsApp:onShare:onDismiss:)
    init(
        content: PPVetViewerContent,
        onCall: @escaping () -> Void,
        onWhatsApp: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        let presentation = PPVetViewerPresentation(content: content)
        self.presentation = presentation
        self.contentController = UIHostingController(
            rootView: PPVetViewerScreen(
                presentation: presentation,
                onCall: onCall,
                onWhatsApp: onWhatsApp,
                onShare: onShare,
                onDismiss: onDismiss
            )
        )
        super.init(nibName: nil, bundle: nil)
    }

    @objc required dynamic init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground
        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        contentController.view.backgroundColor = .clear
        view.addSubview(contentController.view)
        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        contentController.didMove(toParent: self)
    }

    @objc(updateWithContent:)
    func update(content: PPVetViewerContent) {
        viewIfLoaded?.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        presentation.update(content: content)
    }
}
