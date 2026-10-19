//
//  PPVetCardView.swift
//  Pure Pets
//
//  Two care-directory compositions: a practitioner note and a practice placard.
//  Presentation only; UIKit retains selection, contact and navigation ownership.
//

import SwiftUI
import UIKit
import ObjectiveC

// Reuse the detail projection so list and profile agree about fees, moderation,
// verification and contact eligibility. This reads cached taxonomy, never Firebase.
struct PPVetCardSnapshot: Equatable {
    let profile: PPVetViewerSnapshot

    init(vet: VetModel, mainKindName: String?, kinds: [MainKindsModel]? = nil) {
        let content = PPVetViewerContent()
        content.vetID = vet.vetID ?? ""
        content.title = vet.title ?? ""
        content.isCompany = vet.type == .company
        content.logoURL = vet.logoURL ?? ""
        content.descriptionText = vet.descriptionText ?? ""
        content.phone = vet.phone ?? ""
        content.whatsapp = vet.whatsapp ?? ""
        content.vetCost = vet.vetCost
        content.readyToContact = vet.readyToContact
        content.isDisabled = vet.isDisabled
        content.verificationStatus = vet.verificationStatus ?? ""
        content.cityName = vet.cityName ?? ""
        content.address = vet.address ?? ""
        content.workingHours = vet.workingHours ?? ""
        content.emergency247 = vet.emergency247
        content.homeVisitAvailable = vet.homeVisitAvailable

        // Legacy taxonomy properties are declared nonnull but older documents
        // can omit one language. Read them as optional Objective-C values before
        // bridging, so an incomplete document cannot trap in Swift.String.
        let taxonomy = (kinds ?? MainKindsArrayManager.shared().visibleMainKindsSnapshot()).map {
            (id: $0.id,
             arabic: ($0.value(forKey: "KindNameAr") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
             english: ($0.value(forKey: "KindNameEn") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let rtl = Language.isRTL()
        func name(for kind: (id: Int, arabic: String, english: String)) -> String {
            let preferred = rtl ? kind.arabic : kind.english
            let fallback = rtl ? kind.english : kind.arabic
            return preferred.isEmpty ? fallback : preferred
        }
        var names: [String] = []
        let identifiers = (vet.supportedKindIDs ?? []).map { $0.stringValue }
        for raw in (vet.animalTypes ?? []) + identifiers {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let digits = value.compactMap { $0.wholeNumberValue }
            let numeric = digits.count == value.count
            let identifier = numeric ? Int(digits.map(String.init).joined()) : nil
            let matched = taxonomy.first {
                if let identifier = identifier { return $0.id == identifier && identifier > 0 }
                return $0.arabic.caseInsensitiveCompare(value) == .orderedSame ||
                    $0.english.caseInsensitiveCompare(value) == .orderedSame
            }
            let resolved = matched.map { name(for: $0) } ?? (numeric ? "" : value)
            if !resolved.isEmpty { names.append(resolved) }
        }
        if let kind = taxonomy.first(where: { $0.id == vet.petMainKindID && $0.id > 0 }) {
            content.mainKindName = name(for: kind)
        } else if vet.petMainKindID > 0, let fallback = mainKindName,
                  fallback != Language.get("pet_care_all_pets", alter: nil) {
            content.mainKindName = fallback
        }
        content.animalTypes = names
        profile = PPVetViewerSnapshot(content: content)
    }
}

private enum PPVetCardStyle {
    static func copy(_ key: String) -> String { PPVetDetailLocalization.text(key) }

    static func font(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle) -> Font {
        .custom(bold ? "Beiruti-Bold" : "Beiruti-Regular", size: size, relativeTo: style)
    }

    static func providerLabel(_ key: String, _ profile: PPVetViewerSnapshot) -> String {
        String(format: copy(key), profile.title)
    }
}

// Apply Bold Text through Font, which supports the iOS 15 deployment target.
// View.fontWeight is only available from iOS 16.
private struct PPVetCardTypography: ViewModifier {
    let size: CGFloat
    let bold: Bool
    let textStyle: Font.TextStyle
    @Environment(\.legibilityWeight) private var legibilityWeight

    func body(content: Content) -> some View {
        content.font(PPVetCardStyle.font(size, bold: bold || legibilityWeight == .bold, relativeTo: textStyle))
    }
}

private extension View {
    func vetCardFont(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle) -> some View {
        modifier(PPVetCardTypography(size: size, bold: bold, textStyle: style))
    }
}

struct PPVetCardView: View {
    let snapshot: PPVetCardSnapshot
    let width: CGFloat
    var isMeasuring = false
    var onDetailsTap: (() -> Void)?
    var onCallTap: (() -> Void)?
    var onWhatsAppTap: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var profile: PPVetViewerSnapshot { snapshot.profile }
    private var stacked: Bool { width < 340 || dynamicTypeSize >= .xxxLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if !profile.isListed {
                    unavailable
                } else if profile.isCompany {
                    PPClinicDiscoveryCard(profile: profile, stacked: stacked, isMeasuring: isMeasuring)
                } else {
                    PPVeterinarianDiscoveryCard(profile: profile, stacked: stacked, isMeasuring: isMeasuring)
                }
            }
            // The information region keeps tap-to-open. Contact controls are
            // siblings, so their taps cannot also select the collection item.
            .contentShape(Rectangle())
            .onTapGesture { onDetailsTap?() }
            PPVetCardActions(profile: profile, stacked: stacked,
                             onDetails: onDetailsTap, onCall: onCallTap, onWhatsApp: onWhatsAppTap)
                .padding(.horizontal, PPSpace.lg)
                .padding(.bottom, PPSpace.base)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .ppElevatedSurface))
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.ppTextSecondary : Color.ppSurfaceBorder,
                              lineWidth: contrast == .increased ? 1.5 : 0.75)
                .allowsHitTesting(false)
        }
        .foregroundStyle(Color.ppTextPrimary)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, profile.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: profile.isRTL ? "ar_QA" : "en_QA"))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("petCare.\(profile.isCompany ? "clinic" : "vet").\(profile.id)")
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(profile.title)
                .vetCardFont(24, bold: true, relativeTo: .title2)
            Text(PPVetCardStyle.copy("vet_detail_unavailable_title"))
                .vetCardFont(16, relativeTo: .body)
                .foregroundStyle(Color.ppTextSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(PPSpace.lg)
    }
}

// A person-led introduction: identity media and biography precede care scope.
private struct PPVeterinarianDiscoveryCard: View {
    let profile: PPVetViewerSnapshot
    let stacked: Bool
    let isMeasuring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            if stacked {
                PPVetCardIdentityImage(profile: profile, width: 88, height: 108, isMeasuring: isMeasuring)
                introduction
            } else {
                HStack(alignment: .top, spacing: PPSpace.base) {
                    PPVetCardIdentityImage(profile: profile, width: 88, height: 108, isMeasuring: isMeasuring)
                    introduction
                }
            }
            PPVetCardScope(profile: profile)
            if let city = profile.cityName {
                PPVetCardFact(symbol: "mappin.and.ellipse", text: city)
            }
            PPVetCardDeclaredServices(profile: profile)
            PPVetCardFee(profile: profile, stacked: stacked)
        }
        .padding(PPSpace.lg)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            PPVetCardRole(profile: profile)
            PPVetCardName(profile: profile, size: 24)
            if !profile.bio.isEmpty {
                PPVetCardIntroduction(text: profile.bio)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// A place-led sign: the clinic name and city lead, with a contained identity stamp.
// Address and published hours have priority over the descriptive introduction.
private struct PPClinicDiscoveryCard: View {
    let profile: PPVetViewerSnapshot
    let stacked: Bool
    let isMeasuring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if stacked {
                    VStack(alignment: .leading, spacing: PPSpace.base) {
                        identity
                        PPVetCardIdentityImage(profile: profile, width: 72, height: 72, isMeasuring: isMeasuring)
                    }
                } else {
                    HStack(alignment: .top, spacing: PPSpace.base) {
                        identity
                        PPVetCardIdentityImage(profile: profile, width: 72, height: 72, isMeasuring: isMeasuring)
                    }
                }
            }
            .padding(PPSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ppSecondarySurface)

            VStack(alignment: .leading, spacing: PPSpace.md) {
                if let address = profile.address {
                    PPVetCardFact(symbol: "mappin.and.ellipse", text: address)
                }
                if let hours = profile.workingHours {
                    PPVetCardFact(symbol: "clock", text: hours,
                                  label: PPVetCardStyle.copy("vet_card_listed_hours"))
                }
                if !profile.bio.isEmpty { PPVetCardIntroduction(text: profile.bio) }
                PPVetCardScope(profile: profile)
                PPVetCardDeclaredServices(profile: profile)
                PPVetCardFee(profile: profile, stacked: stacked)
            }
            .padding(PPSpace.lg)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            PPVetCardRole(profile: profile)
            PPVetCardName(profile: profile, size: 26)
            if let city = profile.cityName {
                Text(city)
                    .vetCardFont(16, relativeTo: .body)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PPVetCardName: View {
    let profile: PPVetViewerSnapshot
    let size: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(profile.title)
            .vetCardFont(size, bold: true, relativeTo: .title2)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(profile.title)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PPVetCardIntroduction: View {
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(text)
            .vetCardFont(16, relativeTo: .body)
            .foregroundStyle(Color.ppTextSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PPVetCardRole: View {
    let profile: PPVetViewerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Label(PPVetCardStyle.copy(profile.isCompany ? "vet_detail_clinic" : "vet_detail_doctor"),
                  systemImage: profile.isCompany ? "building.2" : "stethoscope")
                .foregroundStyle(Color.ppPrimary)
            if profile.isVerified {
                Label(PPVetCardStyle.copy("vet_detail_profile_verified"), systemImage: "checkmark.seal")
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .vetCardFont(14, bold: true, relativeTo: .caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PPVetCardIdentityImage: View {
    let profile: PPVetViewerSnapshot
    let width: CGFloat
    let height: CGFloat
    let isMeasuring: Bool

    var body: some View {
        ZStack {
            Color.ppSecondarySurface
            if let url = profile.logoURL, !isMeasuring {
                AppRemoteImage(urlString: url, displaySize: CGSize(width: width, height: height),
                               contentMode: .fit, showsRetryAction: false,
                               placeholder: { placeholder }, failurePlaceholder: { placeholder })
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: profile.isCompany ? 16 : 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: profile.isCompany ? 16 : 24, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.75)
        }
        // Identity is already named alongside it. No duplicate VoiceOver stop or nested retry button.
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: profile.isCompany ? "building.2" : "stethoscope")
            .font(.system(size: 28, weight: .light))
            .foregroundStyle(Color.ppTextSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.ppSecondarySurface)
    }
}

private struct PPVetCardFact: View {
    let symbol: String
    let text: String
    var label: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(.subheadline, design: .default))
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let label = label {
                    Text(label)
                        .vetCardFont(14, relativeTo: .caption)
                        .foregroundStyle(Color.ppTextSecondary)
                }
                Text(text)
                    .vetCardFont(16, relativeTo: .body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct PPVetCardScope: View {
    let profile: PPVetViewerSnapshot

    var body: some View {
        if !profile.speciesSummary.isEmpty {
            PPVetCardFact(symbol: "pawprint", text: profile.speciesSummary,
                          label: PPVetCardStyle.copy("vet_detail_scope"))
        }
    }
}

private struct PPVetCardDeclaredServices: View {
    let profile: PPVetViewerSnapshot

    var body: some View {
        if profile.emergency247 || profile.homeVisitAvailable {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                if profile.emergency247 {
                    PPVetCardFact(symbol: "cross.case", text: PPVetCardStyle.copy("vet_card_emergency"))
                }
                if profile.homeVisitAvailable {
                    PPVetCardFact(symbol: "house", text: PPVetCardStyle.copy("vet_card_home_visits"))
                }
            }
        }
    }
}

private struct PPVetCardFee: View {
    let profile: PPVetViewerSnapshot
    let stacked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Divider().overlay(Color.ppSurfaceBorder)
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    label
                    amount
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
                    label.frame(maxWidth: .infinity, alignment: .leading)
                    amount
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPVetCardStyle.copy("vet_card_fee"))
        .accessibilityValue(profile.consultationCostText)
    }

    private var label: some View {
        Text(PPVetCardStyle.copy("vet_card_fee"))
            .vetCardFont(14, relativeTo: .caption)
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var amount: some View {
        if let amount = profile.consultationAmountText {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(amount)
                    .vetCardFont(24, bold: true, relativeTo: .title2)
                Text(PPVetCardStyle.copy("vet_detail_currency"))
                    .vetCardFont(14, relativeTo: .caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(PPVetCardStyle.copy("vet_card_confirm_fee"))
                .vetCardFont(16, relativeTo: .body)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PPVetCardActions: View {
    let profile: PPVetViewerSnapshot
    let stacked: Bool
    let onDetails: (() -> Void)?
    let onCall: (() -> Void)?
    let onWhatsApp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Button { onDetails?() } label: {
                HStack(spacing: PPSpace.sm) {
                    Text(PPVetCardStyle.copy(profile.isCompany ? "vet_card_clinic_details" : "vet_card_doctor_details"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: profile.isRTL ? "arrow.left" : "arrow.right")
                        .accessibilityHidden(true)
                }
                .vetCardFont(17, bold: true, relativeTo: .body)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, PPSpace.base)
                .padding(.vertical, PPSpace.sm)
                .frame(minHeight: 48)
                .foregroundStyle(Color.ppPrimary)
                .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.small))
                .contentShape(RoundedRectangle(cornerRadius: PPCorner.small))
            }
            .buttonStyle(PPVetCardButtonStyle())
            .accessibilityLabel(PPVetCardStyle.providerLabel("vet_card_details_a11y", profile))
            .accessibilityIdentifier("petCare.provider.details")

            if profile.isListed {
                if stacked {
                    VStack(spacing: PPSpace.sm) { call; whatsApp }
                } else {
                    HStack(spacing: PPSpace.sm) { call; whatsApp }
                }
                if !profile.canCall || !profile.canWhatsApp {
                    Text(PPVetCardStyle.copy(!profile.canCall ? "vet_card_contact_missing" : "vet_card_whatsapp_missing"))
                        .vetCardFont(14, relativeTo: .caption)
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var call: some View {
        contactButton(symbol: "phone", titleKey: "vet_detail_call", labelKey: "vet_card_call_a11y",
                      hintKey: "vet_detail_call_hint", enabled: profile.canCall,
                      identifier: "petCare.provider.call", action: onCall)
    }

    private var whatsApp: some View {
        contactButton(symbol: "bubble.left.and.bubble.right", titleKey: "vet_detail_whatsapp",
                      labelKey: "vet_card_whatsapp_a11y", hintKey: "vet_detail_whatsapp_hint",
                      enabled: profile.canWhatsApp, identifier: "petCare.provider.whatsapp", action: onWhatsApp)
    }

    private func contactButton(symbol: String, titleKey: String, labelKey: String, hintKey: String,
                               enabled: Bool, identifier: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Label(PPVetCardStyle.copy(titleKey), systemImage: symbol)
                .vetCardFont(17, bold: true, relativeTo: .body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PPSpace.sm)
                .padding(.vertical, PPSpace.sm)
                .frame(minHeight: 48)
                .foregroundStyle(enabled ? Color.ppTextPrimary : Color.ppTextSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: PPCorner.small))
        }
        .buttonStyle(PPVetCardButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(PPVetCardStyle.providerLabel(labelKey, profile))
        .accessibilityHint(PPVetCardStyle.copy(enabled ? hintKey : "vet_detail_channel_missing"))
        .accessibilityIdentifier(identifier)
    }
}

private struct PPVetCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(PPVetCardPressFeedback(isPressed: configuration.isPressed))
    }
}

private struct PPVetCardPressFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.99 : 1)
            .opacity(isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isPressed)
    }
}

// MARK: - Objective-C hosting and intrinsic measurement
@MainActor
@objc(PPVetCardBridge)
public final class PPVetCardBridge: NSObject {
    private static var legacyHostKey: UInt8 = 0
    private struct Measurement {
        let snapshot: PPVetCardSnapshot
        let width: CGFloat
        let category: String
        let legibilityWeight: UILegibilityWeight
        let height: CGFloat
    }
    private static var measurements: [Measurement] = []

    @objc(configureWithCell:vet:mainKindName:onDetailsTap:onCallTap:onWhatsAppTap:)
    public static func configure(cell: UICollectionViewCell, vet: VetModel, mainKindName: String?,
                                 onDetailsTap: (() -> Void)?, onCallTap: (() -> Void)?,
                                 onWhatsAppTap: (() -> Void)?) {
        let snapshot = PPVetCardSnapshot(vet: vet, mainKindName: mainKindName)
        let width = max(1, cell.bounds.width)
        let view = PPVetCardView(snapshot: snapshot, width: width, onDetailsTap: onDetailsTap,
                                 onCallTap: onCallTap, onWhatsAppTap: onWhatsAppTap)
            .environment(\.dynamicTypeSize, dynamicTypeSize(cell.traitCollection.preferredContentSizeCategory.rawValue))
            .environment(\.legibilityWeight, cell.traitCollection.legibilityWeight == .bold ? .bold : .regular)
        if #available(iOS 16.0, *) {
            cell.contentConfiguration = UIHostingConfiguration { view }.margins(.all, 0)
        } else {
            let host: UIHostingController<AnyView>
            if let existing = objc_getAssociatedObject(cell, &legacyHostKey) as? UIHostingController<AnyView> {
                host = existing
                host.rootView = AnyView(view)
            } else {
                host = UIHostingController(rootView: AnyView(view))
                objc_setAssociatedObject(cell, &legacyHostKey, host, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                host.view.backgroundColor = .clear
                host.view.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(host.view)
                NSLayoutConstraint.activate([
                    host.view.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    host.view.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                    host.view.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                    host.view.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
                ])
            }
            cellDidMoveToWindow(cell)
        }
    }

    // Prefetched cells may remain unattached for several run loops. Follow the
    // actual view lifecycle instead of assuming a deferred attempt found a parent.
    @objc(cellDidMoveToWindow:)
    public static func cellDidMoveToWindow(_ cell: UICollectionViewCell) {
        guard let host = objc_getAssociatedObject(cell, &legacyHostKey) as? UIViewController else { return }
        if cell.window != nil {
            attach(host, toParentOf: cell)
        } else if host.parent != nil {
            host.willMove(toParent: nil)
            host.removeFromParent()
        }
    }

    private static func attach(_ host: UIViewController, toParentOf cell: UICollectionViewCell) {
        var responder: UIResponder? = cell.next
        while let current = responder {
            if let parent = current as? UIViewController {
                guard host.parent !== parent else { return }
                if host.parent != nil {
                    host.willMove(toParent: nil)
                    host.removeFromParent()
                }
                parent.addChild(host)
                host.didMove(toParent: parent)
                return
            }
            responder = current.next
        }
    }

    @objc(clearCell:)
    public static func clear(cell: UICollectionViewCell) {
        cell.contentConfiguration = nil
        if let host = objc_getAssociatedObject(cell, &legacyHostKey) as? UIViewController {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }
        objc_setAssociatedObject(cell, &legacyHostKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc(preferredHeightWithVet:mainKindName:width:contentSizeCategory:legibilityWeight:)
    public static func preferredHeight(vet: VetModel, mainKindName: String?, width: CGFloat,
                                       contentSizeCategory: String, legibilityWeight: UILegibilityWeight) -> CGFloat {
        guard width.isFinite, width > 32 else { return 400 }
        let snapshot = PPVetCardSnapshot(vet: vet, mainKindName: mainKindName)
        if let measurement = measurements.last(where: {
            $0.snapshot == snapshot && $0.width == width && $0.category == contentSizeCategory &&
                $0.legibilityWeight == legibilityWeight
        }) { return measurement.height }
        let root = PPVetCardView(snapshot: snapshot, width: width, isMeasuring: true)
            .environment(\.dynamicTypeSize, dynamicTypeSize(contentSizeCategory))
            .environment(\.legibilityWeight, legibilityWeight == .bold ? .bold : .regular)
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: root)
        let result = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = result.height.isFinite && result.height > 0 ? ceil(result.height) + 2 : 600
        if measurements.count >= 128 { measurements.removeFirst() }
        measurements.append(Measurement(snapshot: snapshot, width: width, category: contentSizeCategory,
                                        legibilityWeight: legibilityWeight, height: height))
        return height
    }

    private static func dynamicTypeSize(_ value: String) -> DynamicTypeSize {
        switch UIContentSizeCategory(rawValue: value) {
        case .extraSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .extraLarge: return .xLarge
        case .extraExtraLarge: return .xxLarge
        case .extraExtraExtraLarge: return .xxxLarge
        case .accessibilityMedium: return .accessibility1
        case .accessibilityLarge: return .accessibility2
        case .accessibilityExtraLarge: return .accessibility3
        case .accessibilityExtraExtraLarge: return .accessibility4
        case .accessibilityExtraExtraExtraLarge: return .accessibility5
        default: return .large
        }
    }
}
