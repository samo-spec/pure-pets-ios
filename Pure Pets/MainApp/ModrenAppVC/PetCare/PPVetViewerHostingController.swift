//
//  PPVetViewerHostingController.swift
//  Pure Pets
//
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
    var isDisabled: Bool = false
    var verificationStatus: String = ""
    var subscriptionActive: Bool = false
    var subscriptionTier: Int = 0
    var availableDateText: String = ""
    var availableDate: Date?
    var animalTypes: [String] = []
    var mainKindName: String = ""
    var cityID: String = ""
    var cityName: String = ""
    var workingAreas: [String] = []
    var address: String = ""
    var licenseNumber: String = ""
    var workingHours: String = ""
    var emergency247: Bool = false
    var homeVisitAvailable: Bool = false
}


// A feature table keeps packaging explicit while Language remains the language owner.
// The legacy lookup supports older resources; a missing translation never becomes a UI identifier.
@objc(PPVetDetailLocalization)
final class PPVetDetailLocalization: NSObject {
    @objc(textForKey:)
    static func text(_ key: String) -> String {
        resolvedText(for: key) { candidate, table in
            if let table = table { return Language.get(candidate, table: table, alter: nil) }
            return Language.get(candidate, alter: nil)
        }
    }

    static func resolvedText(for key: String, lookup: (String, String?) -> String?) -> String {
        func translated(_ candidate: String, table: String?) -> String? {
            guard let value = lookup(candidate, table), value != candidate,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        if let value = translated(key, table: "VetDetails") ?? translated(key, table: nil) { return value }
        // Format-only fallbacks preserve supplied data without leaking a resource key.
        if ["vet_detail_share_phone", "vet_detail_share_whatsapp", "vet_detail_image_label"].contains(key) {
            return "\u{2066}%@\u{2069}"
        }
        return translated(fallbackKeys[key] ?? "details", table: nil) ?? ""
    }

    private static let fallbackKeys: [String: String] = [
        "vet_card_doctor_details": "details",
        "vet_card_clinic_details": "details",
        "vet_card_fee": "pet_care_vet_viewer_cost",
        "vet_card_confirm_fee": "pet_care_viewer_not_specified",
        "vet_card_listed_hours": "pet_care_vet_viewer_available_date",
        "vet_card_emergency": "pet_care_vet_viewer_about",
        "vet_card_home_visits": "pet_care_vet_viewer_about",
        "vet_card_details_a11y": "details",
        "vet_card_call_a11y": "pet_care_call",
        "vet_card_whatsapp_a11y": "pet_care_whatsapp",
        "vet_card_contact_missing": "pet_care_vet_viewer_contact_unavailable",
        "vet_card_whatsapp_missing": "pet_care_vet_viewer_contact_unavailable",
        "vet_card_contact_error_body": "error_please_try_again_in_a_moment",
        "vet_detail_clinic": "pet_care_vet_company",
        "vet_detail_doctor": "pet_care_vet_untitled",
        "vet_detail_clinic_intro": "pet_care_vet_company",
        "vet_detail_doctor_intro": "pet_care_vet_untitled",
        "vet_detail_profile": "pet_care_vet_viewer_profile",
        "vet_detail_profile_verified": "pet_care_vet_viewer_verified",
        "vet_detail_back": "chat_header_back",
        "vet_detail_share": "share",
        "vet_detail_image_loading": "loading_images",
        "vet_detail_image_missing": "pet_care_viewer_not_specified",
        "vet_detail_about_clinic": "pet_care_vet_viewer_about",
        "vet_detail_about_doctor": "pet_care_vet_viewer_about",
        "vet_detail_bio_missing": "pet_care_viewer_no_description",
        "vet_detail_read_more": "ReadMore",
        "vet_detail_read_less": "details",
        "vet_detail_animals": "pet_care_viewer_pet_kind",
        "vet_detail_scope": "pet_care_viewer_pet_kind",
        "vet_detail_animals_missing": "pet_care_viewer_not_specified",
        "vet_detail_before_contact": "pet_care_vet_viewer_contact",
        "vet_detail_prepare_title": "pet_care_vet_viewer_contact",
        "vet_detail_consultation_fee": "pet_care_vet_viewer_cost",
        "vet_detail_confirm_fee": "pet_care_viewer_not_specified",
        "vet_detail_fee_note": "pet_care_vet_viewer_contact",
        "vet_detail_listed_availability": "pet_care_vet_viewer_available_date",
        "vet_detail_currency": "pet_care_vet_currency",
        "vet_detail_membership": "pet_care_vet_viewer_membership",
        "vet_detail_membership_active": "pet_care_vet_viewer_subscription_active",
        "vet_detail_membership_tier": "pet_care_vet_viewer_subscription_active",
        "vet_detail_phone": "pet_care_call",
        "vet_detail_whatsapp": "pet_care_whatsapp",
        "vet_detail_contact_title": "pet_care_vet_viewer_contact",
        "vet_detail_contact_enabled": "pet_care_vet_contact_ready",
        "vet_detail_confirm_visit": "pet_care_vet_viewer_contact",
        "vet_detail_get_in_touch": "pet_care_vet_viewer_contact",
        "vet_detail_contact_missing": "pet_care_vet_viewer_contact_unavailable",
        "vet_detail_call": "pet_care_call",
        "vet_detail_call_hint": "pet_care_call",
        "vet_detail_whatsapp_hint": "pet_care_whatsapp",
        "vet_detail_channel_missing": "pet_care_vet_viewer_contact_unavailable",
        "vet_detail_whatsapp_international": "pet_care_call",
        "vet_detail_unavailable_title": "pet_care_vet_viewer_contact_unavailable",
        "vet_detail_unavailable_body": "pet_care_directory_empty_vets_body",
        "vet_detail_contact_error_title": "error",
        "vet_detail_contact_error_body": "error_please_try_again_in_a_moment"
    ]
}

// One normalization contract for rendered availability and the UIKit action owner.
// Preserve international prefixes; never guess a country code from the UI locale.
@objc(PPVetContactRouting)
final class PPVetContactRouting: NSObject {
    @objc(normalizedPhone:)
    static func normalizedPhone(_ raw: String) -> String? {
        var result = ""
        let separators = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "()-.\u{200E}\u{200F}\u{061C}\u{2066}\u{2067}\u{2068}\u{2069}")
        )
        for character in raw {
            if character.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
               let value = character.wholeNumberValue, (0...9).contains(value) {
                result.append(String(value))
            } else if character == "+", result.isEmpty {
                result.append(character)
            } else if !character.unicodeScalars.allSatisfy({ separators.contains($0) }) {
                return nil
            }
        }
        if result.hasPrefix("00") { result = "+" + String(result.dropFirst(2)) }
        let digits = result.filter { $0.isNumber }
        guard (7...15).contains(digits.count) else { return nil }
        return result
    }

    @objc(callURLWithPhone:whatsapp:)
    static func callURL(phone: String, whatsapp: String) -> URL? {
        guard let number = normalizedPhone(phone) ?? normalizedPhone(whatsapp) else { return nil }
        return URL(string: "tel:\(number)")
    }

    @objc(whatsAppURLWithPhone:whatsapp:)
    static func whatsAppURL(phone: String, whatsapp: String) -> URL? {
        // wa.me accepts digits only, without '+' or the international '00' prefix.
        for raw in [whatsapp, phone] {
            guard let number = normalizedPhone(raw) else { continue }
            let digits = number.filter { $0.isNumber }
            // Legacy international numbers may omit '+'. Short local numbers remain callable,
            // but cannot form a WhatsApp address without guessing a country code.
            guard !digits.hasPrefix("0"), number.hasPrefix("+") || digits.count >= 10 else { continue }
            return URL(string: "https://wa.me/\(digits)")
        }
        return nil
    }

    @objc(isContactAllowedWithStatus:disabled:)
    static func isContactAllowed(status: String, disabled: Bool) -> Bool {
        let status = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !disabled && ["", "approved", "active", "verified"].contains(status)
    }
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
        view.semanticContentAttribute = Language.semanticAttributeForCurrentLanguage()
        addChild(contentController)
        contentController.view.translatesAutoresizingMaskIntoConstraints = false
        contentController.view.backgroundColor = .clear
        view.addSubview(contentController.view)
        NSLayoutConstraint.activate([
            contentController.view.topAnchor.constraint(equalTo: view.topAnchor),
            contentController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
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
