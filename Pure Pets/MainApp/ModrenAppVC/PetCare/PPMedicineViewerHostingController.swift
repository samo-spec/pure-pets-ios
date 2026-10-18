import Combine
import SwiftUI
import UIKit

/// Presentation input only. The Objective-C controller retains the medicine,
/// CartManager, authentication, quantity validation, and navigation ownership.
@objc(PPMedicineViewerContent)
@objcMembers
final class PPMedicineViewerContent: NSObject {
    var identifier = ""
    var title = ""
    var category = ""
    var speciesNames: [String] = []
    var discoveryContext = ""
    var descriptionText = ""
    var imageURL = ""
    var displayPrice = ""
    var addedDateText = ""
    var stockQuantity = 0
    var cartQuantity = 0
    var purchaseEligible = false
    var canReturnToCare = false
}

enum PPMedicineViewerL10n {
    static func text(_ key: String) -> String {
        Language.get(key, alter: nil) ?? key
    }

    static func format(_ key: String, _ value: String) -> String {
        String(format: text(key), locale: locale, value)
    }

    static var locale: Locale {
        Locale(identifier: Language.currentLanguageCode())
    }

    static func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Isolate short catalog values without changing their actual characters.
    /// Do not force English direction onto the surrounding Arabic composition.
    static func isolated(_ value: String) -> String {
        "\u{2068}\(value)\u{2069}"
    }
}

struct PPMedicineViewerSnapshot: Equatable {
    enum Availability: Equatable {
        case available, unavailable, soldOut, allInCart
    }

    let identifier: String
    let title: String
    let category: String
    let species: String
    let discoveryContext: String
    let descriptionText: String
    let imageURL: String
    let displayPrice: String
    let addedDateText: String
    let stockText: String
    let cartText: String
    let availability: Availability
    let canReturnToCare: Bool
    let languageCode: String
    let isRTL: Bool

    init(content: PPMedicineViewerContent) {
        func clean(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        identifier = clean(content.identifier)
        let suppliedTitle = clean(content.title)
        title = suppliedTitle.isEmpty
            ? PPMedicineViewerL10n.text("pet_care_medicine_untitled")
            : suppliedTitle
        category = clean(content.category)
        discoveryContext = clean(content.discoveryContext)
        descriptionText = clean(content.descriptionText)
        let suppliedImageURL = clean(content.imageURL)
        if let url = URL(string: suppliedImageURL),
           let scheme = url.scheme?.lowercased(),
           (scheme == "https" || scheme == "http"),
           let host = url.host, !host.isEmpty {
            imageURL = suppliedImageURL
        } else {
            // AppRemoteImage has no retry action when normalization rejects a
            // URL. Keep that state honest instead of showing an inert retry.
            imageURL = ""
        }
        displayPrice = content.displayPrice
        addedDateText = content.addedDateText
        canReturnToCare = content.canReturnToCare
        languageCode = Language.currentLanguageCode()
        isRTL = Language.isRTL()

        var seen = Set<String>()
        let names = content.speciesNames.map(clean).filter {
            !$0.isEmpty && seen.insert($0).inserted
        }
        let listFormatter = ListFormatter()
        listFormatter.locale = PPMedicineViewerL10n.locale
        species = listFormatter.string(
            from: names.map(PPMedicineViewerL10n.isolated)
        ) ?? names.joined(separator: PPMedicineViewerL10n.text("medicine_record_list_separator"))

        let stock = max(0, content.stockQuantity)
        let inCart = max(0, content.cartQuantity)
        stockText = PPMedicineViewerL10n.format(
            "medicine_record_stock_format", PPMedicineViewerL10n.number(stock)
        )
        cartText = inCart > 0
            ? PPMedicineViewerL10n.format(
                "medicine_record_cart_format", PPMedicineViewerL10n.number(inCart)
            )
            : ""

        if !content.purchaseEligible {
            availability = .unavailable
        } else if stock == 0 {
            availability = .soldOut
        } else if inCart >= stock {
            availability = .allInCart
        } else {
            availability = .available
        }
    }
}

@MainActor
final class PPMedicineViewerPresentation: ObservableObject {
    @Published private(set) var snapshot: PPMedicineViewerSnapshot

    init(content: PPMedicineViewerContent) {
        snapshot = PPMedicineViewerSnapshot(content: content)
    }

    func update(content: PPMedicineViewerContent) {
        let next = PPMedicineViewerSnapshot(content: content)
        guard next != snapshot else { return }
        // Keep the hosting root and scroll identity through cart/language changes.
        snapshot = next
    }
}

@MainActor
@objc(PPMedicineViewerHostingController)
final class PPMedicineViewerHostingController: UIViewController {
    private let presentation: PPMedicineViewerPresentation
    private let contentController: UIHostingController<PPMedicineViewerScreen>

    @objc(initWithContent:onReturnToCare:)
    init(content: PPMedicineViewerContent, onReturnToCare: @escaping () -> Void) {
        let presentation = PPMedicineViewerPresentation(content: content)
        self.presentation = presentation
        contentController = UIHostingController(rootView: PPMedicineViewerScreen(
            presentation: presentation, onReturnToCare: onReturnToCare
        ))
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
        contentController.view.backgroundColor = .ppBackground
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
    func update(content: PPMedicineViewerContent) {
        viewIfLoaded?.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        presentation.update(content: content)
    }
}
