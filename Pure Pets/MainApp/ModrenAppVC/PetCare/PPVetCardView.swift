//
//  PPVetCardView.swift
//  Pure Pets
//
//  Reinvented from absolute first principles for NextGen V6 Flagship.
//  Category-defining clinical specialist card in SwiftUI with live beacon aura,
//  verified credentials, species scope, and tactile action rail.
//

import SwiftUI

// MARK: - Species Item
struct PPVetSpeciesItem: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String

    static func resolve(from rawName: String, isRTL: Bool) -> PPVetSpeciesItem {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("cat") || lower.contains("قط") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "القطط" : "Cats",
                iconName: "cat.fill"
            )
        } else if lower.contains("dog") || lower.contains("كلب") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الكلاب" : "Dogs",
                iconName: "dog.fill"
            )
        } else if lower.contains("bird") || lower.contains("طير") || lower.contains("طائر") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الطيور" : "Birds",
                iconName: "bird.fill"
            )
        } else if lower.contains("horse") || lower.contains("خيل") || lower.contains("فرس") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الخيول" : "Horses",
                iconName: "figure.equestrian.sports"
            )
        } else if lower.contains("rabbit") || lower.contains("أرنب") || lower.contains("hamster") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الأرانب والقوارض" : "Rabbits & Small",
                iconName: "hare.fill"
            )
        } else if lower.contains("reptile") || lower.contains("زواحف") || lower.contains("زاحف") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الزواحف" : "Reptiles",
                iconName: "lizard.fill"
            )
        } else if lower.contains("fish") || lower.contains("سمك") {
            return PPVetSpeciesItem(
                id: trimmed,
                name: isRTL ? "الأسماك" : "Aquatics",
                iconName: "fish.fill"
            )
        }
        return PPVetSpeciesItem(
            id: trimmed,
            name: trimmed,
            iconName: "pawprint.fill"
        )
    }
}

// MARK: - Snapshot
struct PPVetCardSnapshot: Equatable {
    let id: String
    let title: String
    let isCompany: Bool
    let typeBadgeText: String
    let logoURL: String
    let subtitle: String
    let costText: String
    let isFreeConsult: Bool
    let isReadyToContact: Bool
    let canCall: Bool
    let canWhatsApp: Bool
    let isVerified: Bool
    let speciesList: [PPVetSpeciesItem]
    let languageCode: String
    let isRTL: Bool

    init(vet: VetModel, mainKindName: String?) {
        let isRTL = Language.isRTL()
        self.isRTL = isRTL
        self.languageCode = Language.currentLanguageCode()

        self.id = vet.vetID ?? UUID().uuidString
        let rawTitle = (vet.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = rawTitle.isEmpty
            ? (Language.get("pet_care_vet_untitled", alter: nil) ?? (isRTL ? "طبيب بيطري" : "Veterinarian"))
            : rawTitle

        self.isCompany = (vet.type == .company)
        if self.isCompany {
            self.typeBadgeText = Language.get("pet_care_vet_verified_clinic", alter: nil) ?? (isRTL ? "منشأة بيطرية معتمدة" : "Accredited Clinic")
        } else {
            self.typeBadgeText = Language.get("pet_care_vet_verified_doctor", alter: nil) ?? (isRTL ? "طبيب بيطري معتمد" : "Certified Doctor")
        }

        self.logoURL = (vet.logoURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let rawDesc = (vet.descriptionText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitle = rawDesc.isEmpty
            ? (Language.get("pet_care_vet_default_subtitle", alter: nil) ?? (isRTL ? "مزود رعاية جاهز لدعم صحة الحيوانات." : "Care provider ready for pet health support."))
            : rawDesc

        let currency = Language.get("pet_care_vet_currency", alter: nil) ?? (isRTL ? "ر.ق" : "QAR")
        if vet.vetCost <= 0.0 {
            self.isFreeConsult = true
            self.costText = Language.get("pet_care_vet_free_consult", alter: nil) ?? (isRTL ? "استشارة مجانية" : "Free Consultation")
        } else {
            self.isFreeConsult = false
            let numFormatted = PPVetCardSnapshot.formatNumber(vet.vetCost, isRTL: isRTL)
            self.costText = "\(numFormatted) \(currency)"
        }

        self.isReadyToContact = vet.readyToContact
        let phone = (vet.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let whatsapp = (vet.whatsapp ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.canCall = !phone.isEmpty || !whatsapp.isEmpty
        self.canWhatsApp = !whatsapp.isEmpty || !phone.isEmpty

        let verStatus = (vet.verificationStatus ?? "").lowercased()
        self.isVerified = verStatus == "verified" || verStatus == "approved" || vet.subscriptionActive

        var species: [PPVetSpeciesItem] = []
        if let animals = vet.animalTypes, !animals.isEmpty {
            for animal in animals {
                let item = PPVetSpeciesItem.resolve(from: animal, isRTL: isRTL)
                if !species.contains(where: { $0.id == item.id }) {
                    species.append(item)
                }
            }
        }
        if species.isEmpty, let mainKind = mainKindName, !mainKind.isEmpty {
            species.append(PPVetSpeciesItem.resolve(from: mainKind, isRTL: isRTL))
        }
        self.speciesList = species
    }

    private static func formatNumber(_ value: Double, isRTL: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: isRTL ? "ar" : "en")
        formatter.numberStyle = .decimal
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - SwiftUI View
struct PPVetCardView: View {
    let snapshot: PPVetCardSnapshot
    var onDetailsTap: (() -> Void)?
    var onCallTap: (() -> Void)?
    var onWhatsAppTap: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed: Bool = false
    @State private var pulseState: Bool = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: {
            onDetailsTap?()
        }) {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                // Top Row: Avatar + Info + Fee Pill
                HStack(alignment: .top, spacing: PPSpace.md) {
                    avatarWithLiveBeacon
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Eyebrow / Verification Chip
                        HStack(spacing: 5) {
                            Image(systemName: snapshot.isCompany ? "building.2.crop.circle.fill" : "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(snapshot.isVerified ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.ppCareAccent)
                            
                            Text(snapshot.typeBadgeText)
                                .font(customFont(11, bold: true, relativeTo: .caption2))
                                .foregroundStyle(snapshot.isVerified ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.ppCareAccent)
                                .lineLimit(1)
                            
                            Spacer(minLength: 4)
                            
                            // Fee Pill
                            feePill
                        }
                        
                        // Doctor / Clinic Title
                        Text(snapshot.title)
                            .font(customFont(17, bold: true, relativeTo: .headline))
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        
                        // Subtitle / Bio
                        Text(snapshot.subtitle)
                            .font(customFont(12.5, bold: false, relativeTo: .subheadline))
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(2)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Middle: Treated Species Chips (if available)
                if !snapshot.speciesList.isEmpty {
                    speciesRow
                }

                // Divider line
                Rectangle()
                    .fill(Color.ppSeparator.opacity(isDark ? 0.35 : 0.6))
                    .frame(height: 0.75)

                // Bottom Action Rail: Call, WhatsApp, View Details
                HStack(spacing: PPSpace.sm) {
                    // Call Button
                    Button(action: {
                        onCallTap?()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text(snapshot.isRTL ? "اتصال" : "Call")
                                .font(customFont(13, bold: true, relativeTo: .caption))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(snapshot.canCall ? Color.ppCareAccent : Color.ppTextTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .fill(snapshot.canCall ? Color.ppCareAccent.opacity(isDark ? 0.16 : 0.08) : Color.ppSecondarySurface)
                        )
                    }
                    .buttonStyle(PPScaleButtonStyle())
                    .disabled(!snapshot.canCall)
                    .accessibilityLabel(snapshot.isRTL ? "اتصال بالطبيب" : "Call veterinarian")

                    // WhatsApp Button
                    Button(action: {
                        onWhatsAppTap?()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text(snapshot.isRTL ? "واتساب" : "WhatsApp")
                                .font(customFont(13, bold: true, relativeTo: .caption))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(snapshot.canWhatsApp ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.ppTextTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .fill(snapshot.canWhatsApp ? Color(red: 0.15, green: 0.68, blue: 0.38).opacity(isDark ? 0.18 : 0.10) : Color.ppSecondarySurface)
                        )
                    }
                    .buttonStyle(PPScaleButtonStyle())
                    .disabled(!snapshot.canWhatsApp)
                    .accessibilityLabel(snapshot.isRTL ? "محادثة واتساب" : "WhatsApp chat")

                    // Details Action Pill
                    Button(action: {
                        onDetailsTap?()
                    }) {
                        HStack(spacing: 5) {
                            Text(snapshot.isRTL ? "التفاصيل" : "Details")
                                .font(customFont(13, bold: true, relativeTo: .caption))
                            Image(systemName: snapshot.isRTL ? "chevron.left" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .foregroundStyle(Color.ppTextPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                                .fill(Color.ppSecondarySurface)
                        )
                    }
                    .buttonStyle(PPScaleButtonStyle())
                    .accessibilityLabel(snapshot.isRTL ? "عرض تفاصيل الملف" : "View profile details")
                }
            }
            .padding(PPSpace.base)
            .background(
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .fill(Color(uiColor: .ppElevatedSurface))
                    .shadow(color: Color.black.opacity(isDark ? 0.18 : 0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                    .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.45 : 0.75), lineWidth: 0.8)
            )
        }
        .buttonStyle(PPCardPressButtonStyle())
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: snapshot.languageCode))
        .onAppear {
            if snapshot.isReadyToContact {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulseState = true
                }
            }
        }
    }

    // MARK: - Subviews

    private var avatarWithLiveBeacon: some View {
        ZStack(alignment: .topTrailing) {
            // Squircle Avatar
            ZStack {
                if !snapshot.logoURL.isEmpty {
                    AppRemoteImage(
                        urlString: snapshot.logoURL,
                        displaySize: CGSize(width: 58, height: 58),
                        contentMode: .fill
                    )
                } else {
                    avatarFallback
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
            )

            // Live Beacon Dot
            if snapshot.isReadyToContact {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.80, blue: 0.45).opacity(pulseState ? 0.35 : 0.10))
                        .frame(width: 18, height: 18)
                        .scaleEffect(pulseState ? 1.3 : 0.9)

                    Circle()
                        .fill(Color(red: 0.13, green: 0.80, blue: 0.45))
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                }
                .offset(x: snapshot.isRTL ? -2 : 2, y: -2)
            }
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Color.ppCareAccent.opacity(isDark ? 0.18 : 0.09)
            Image(systemName: snapshot.isCompany ? "cross.case.fill" : "stethoscope")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(Color.ppCareAccent)
        }
    }

    private var feePill: some View {
        HStack(spacing: 3) {
            Text(snapshot.costText)
                .font(customFont(11.5, bold: true, relativeTo: .caption2))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .foregroundStyle(snapshot.isFreeConsult ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.ppCareAccent)
        .background(
            Capsule()
                .fill(snapshot.isFreeConsult
                      ? Color(red: 0.15, green: 0.68, blue: 0.38).opacity(isDark ? 0.18 : 0.10)
                      : Color.ppCareAccent.opacity(isDark ? 0.16 : 0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    snapshot.isFreeConsult
                        ? Color(red: 0.15, green: 0.68, blue: 0.38).opacity(0.24)
                        : Color.ppCareAccent.opacity(0.20),
                    lineWidth: 0.6
                )
        )
    }

    private var speciesRow: some View {
        HStack(spacing: 6) {
            ForEach(snapshot.speciesList.prefix(4)) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.iconName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.ppCareAccent)
                    Text(item.name)
                        .font(customFont(11, bold: false, relativeTo: .caption2))
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.ppSecondarySurface)
                )
            }
            if snapshot.speciesList.count > 4 {
                Text("+\(snapshot.speciesList.count - 4)")
                    .font(customFont(10.5, bold: true, relativeTo: .caption2))
                    .foregroundStyle(Color.ppTextSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.ppSecondarySurface)
                    )
            }
            Spacer(minLength: 0)
        }
    }

    private func customFont(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle) -> Font {
        .custom(bold ? "Beiruti-Bold" : "Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Button Styles
private struct PPCardPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

private struct PPScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Objective-C Bridge
@objc(PPVetCardBridge)
@objcMembers
public final class PPVetCardBridge: NSObject {
    @objc(configureWithCell:vet:mainKindName:onDetailsTap:onCallTap:onWhatsAppTap:)
    public static func configure(
        cell: UICollectionViewCell,
        vet: VetModel,
        mainKindName: String?,
        onDetailsTap: (() -> Void)?,
        onCallTap: (() -> Void)?,
        onWhatsAppTap: (() -> Void)?
    ) {
        let snapshot = PPVetCardSnapshot(vet: vet, mainKindName: mainKindName)
        let cardView = PPVetCardView(
            snapshot: snapshot,
            onDetailsTap: onDetailsTap,
            onCallTap: onCallTap,
            onWhatsAppTap: onWhatsAppTap
        )
        if #available(iOS 16.0, *) {
            cell.contentConfiguration = UIHostingConfiguration {
                cardView
            }
            .margins(.all, 0)
        } else {
            let hostingTag = 987123
            if let hostView = cell.contentView.viewWithTag(hostingTag) {
                hostView.removeFromSuperview()
            }
            let host = UIHostingController(rootView: cardView)
            host.view.tag = hostingTag
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
    }

    @objc(preferredHeightWithVet:mainKindName:width:isAccessibility:)
    public static func preferredHeight(
        vet: VetModel,
        mainKindName: String?,
        width: CGFloat,
        isAccessibility: Bool
    ) -> CGFloat {
        if isAccessibility {
            return 280.0
        }
        let hasSpecies = (vet.animalTypes != nil && !(vet.animalTypes?.isEmpty ?? true)) || (mainKindName != nil && !(mainKindName?.isEmpty ?? true))
        return hasSpecies ? 208.0 : 176.0
    }
}

