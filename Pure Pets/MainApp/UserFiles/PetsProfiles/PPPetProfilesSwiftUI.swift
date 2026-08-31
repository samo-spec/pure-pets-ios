//
//  PPPetProfilesSwiftUI.swift
//  Pure Pets
//
//  Pet profile list surface. The Objective-C controller remains the
//  navigation, persistence, and side-effect owner; this file owns only the
//  visual composition and state rendering.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Localized copy

func PPPetLang(_ key: String, fallback: String? = nil) -> String {
    let value = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    if value == key, let fallback {
        return fallback
    }
    return value
}

func PPPetCountText(_ key: String, count: Int) -> String {
    String(format: PPPetLang(key), count)
}

// MARK: - Shared pet-profile visual language

enum PPPetProfileMetrics {
    static let contentMaxWidth: CGFloat = 760
    static let screenMargin: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let smallRadius: CGFloat = 16
    static let controlHeight: CGFloat = 48
    static let minimumHitSize: CGFloat = 44
}

enum PPPetProfileFont {
    static func largeTitle() -> Font {
        .custom("Beiruti-Bold", size: 32, relativeTo: .largeTitle)
    }

    static func title() -> Font {
        .custom("Beiruti-Bold", size: 23, relativeTo: .title2)
    }

    static func headline() -> Font {
        .custom("Beiruti-Bold", size: 18, relativeTo: .headline)
    }

    static func body() -> Font {
        .custom("Beiruti-Regular", size: 17, relativeTo: .body)
    }

    static func medium() -> Font {
        .custom("Beiruti-Medium", size: 15, relativeTo: .subheadline)
    }

    static func footnote() -> Font {
        .custom("Beiruti-Regular", size: 13, relativeTo: .footnote)
    }

    static func caption() -> Font {
        .custom("Beiruti-Bold", size: 12, relativeTo: .caption)
    }
}

private struct PPPetProfileSurfaceModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color
    let elevation: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let border = contrast == .increased
            ? Color.ppTextPrimary.opacity(0.52)
            : Color.ppSurfaceBorder.opacity(colorScheme == .dark ? 0.92 : 0.76)
        let shadowColor = contrast == .increased || !elevation
            ? Color.clear
            : Color.black.opacity(colorScheme == .dark ? 0.20 : 0.055)

        return content
            .background(shape.fill(tint))
            .clipShape(shape)
            .overlay(shape.strokeBorder(border, lineWidth: contrast == .increased ? 1.5 : 0.8))
            .shadow(color: shadowColor, radius: elevation ? 18 : 0, x: 0, y: elevation ? 8 : 0)
    }
}

extension View {
    func ppPetSurface(
        radius: CGFloat = PPPetProfileMetrics.cardRadius,
        tint: Color = .ppSurface,
        elevation: Bool = true
    ) -> some View {
        modifier(PPPetProfileSurfaceModifier(radius: radius, tint: tint, elevation: elevation))
    }
}

private struct PPPetProfileGlassModifier: ViewModifier {
    let radius: CGFloat
    let tint: Color
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if swift(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: .rect(cornerRadius: radius)
            )
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .background(tint.opacity(0.12), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.42), lineWidth: 0.8))
    }
}

extension View {
    /// Glass is reserved for high-priority controls and selected/default
    /// states. Ordinary content stays on the semantic surface system.
    func ppPetGlass(
        radius: CGFloat = PPPetProfileMetrics.smallRadius,
        tint: Color = .clear,
        interactive: Bool = false
    ) -> some View {
        modifier(PPPetProfileGlassModifier(radius: radius, tint: tint, interactive: interactive))
    }
}

struct PPPetProfilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.48)
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled ? 1 : 0.975
            )
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct PPPetProfilePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PPPetProfileFont.medium())
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ppPrimary)
            )
            .shadow(
                color: isEnabled ? Color.ppPrimary.opacity(0.20) : .clear,
                radius: isEnabled ? 10 : 0,
                x: 0,
                y: isEnabled ? 5 : 0
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.44)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct PPPetProfileIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: PPPetProfileMetrics.minimumHitSize, height: PPPetProfileMetrics.minimumHitSize)
                .contentShape(Circle())
        }
        .buttonStyle(PPPetProfilePressStyle())
        .ppPetGlass(radius: PPPetProfileMetrics.minimumHitSize / 2, tint: tint, interactive: true)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PPPetProfileNavigationHeader: View {
    let title: String
    let onBack: () -> Void
    let trailing: AnyView

    var body: some View {
        HStack(spacing: 12) {
            PPPetProfileIconButton(
                systemName: "chevron.backward",
                accessibilityLabel: PPPetLang("Back"),
                tint: .ppTextPrimary,
                action: onBack
            )

            Text(title)
                .font(PPPetProfileFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            trailing
                .frame(minWidth: PPPetProfileMetrics.minimumHitSize)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.ppBackground.opacity(0.96))
    }
}

struct PPPetProfileCanvas<Content: View>: View {
    let content: () -> Content

    var body: some View {
        ZStack {
            Color.ppBackground.ignoresSafeArea()

            GeometryReader { proxy in
                Circle()
                    .fill(Color.ppSoftRose.opacity(0.24))
                    .frame(width: min(proxy.size.width * 0.82, 360))
                    .blur(radius: 34)
                    .offset(x: proxy.size.width * 0.34, y: -proxy.size.height * 0.12)
                    .accessibilityHidden(true)
            }
            .allowsHitTesting(false)

            content()
        }
    }
}

// MARK: - List state

final class PPPetProfilesListStore: ObservableObject {
    @Published private(set) var pets: [PPPetProfile] = []
    @Published private(set) var isLoading = true
    @Published private(set) var hasError = false
    @Published private(set) var images: [String: UIImage] = [:]

    func update(
        pets: [PPPetProfile],
        isLoading: Bool,
        hasError: Bool,
        images: [String: UIImage]
    ) {
        self.pets = pets
        self.isLoading = isLoading
        self.hasError = hasError
        self.images = images
    }
}

@objc(PPPetProfilesSwiftUIImageKey)
public final class PPPetProfilesSwiftUIImageKey: NSObject {
    @objc(keyForPet:)
    public static func key(for pet: PPPetProfile) -> String {
        let petID = pet.petID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !petID.isEmpty {
            return petID
        }

        let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return "name-\(name)"
        }

        return "transient-\(ObjectIdentifier(pet).hashValue)"
    }
}

private extension PPPetProfile {
    var ppStableIdentifier: String {
        PPPetProfilesSwiftUIImageKey.key(for: self)
    }

    var ppDisplayName: String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? PPPetLang("pet_name_placeholder") : value
    }

    var ppDisplayBreed: String {
        let primary = (breed ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        let category = (categoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return category.isEmpty ? PPPetLang("pet_breed_unknown") : category
    }

    var ppDisplayDetail: String {
        let age = displayAgeText()
        return age.isEmpty ? ppDisplayBreed : "\(ppDisplayBreed)  •  \(age)"
    }
}

private struct PPPetProfilesLoadingState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.ppPrimary)
                Text(PPPetLang("Loading"))
                    .font(PPPetProfileFont.medium())
                    .foregroundStyle(Color.ppTextSecondary)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.ppSurfaceBorder.opacity(0.42))
                        .frame(width: 116, height: 116)
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ppSurfaceBorder.opacity(0.50))
                            .frame(maxWidth: 170)
                            .frame(height: 22)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ppSurfaceBorder.opacity(0.34))
                            .frame(maxWidth: 220)
                            .frame(height: 15)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.ppSurfaceBorder.opacity(0.32))
                            .frame(maxWidth: 136)
                            .frame(height: 26)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ppSurfaceBorder.opacity(0.30))
                        .frame(maxWidth: .infinity, minHeight: 54)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ppSurfaceBorder.opacity(0.30))
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
            }
            .padding(20)
            .ppPetSurface(radius: 30, tint: Color.ppSurfaceRaised, elevation: false)
            .accessibilityHidden(true)

            ForEach(["loading.first", "loading.second"], id: \.self) { _ in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.ppSurfaceBorder.opacity(0.38))
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ppSurfaceBorder.opacity(0.44))
                            .frame(maxWidth: 150)
                            .frame(height: 17)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.ppSurfaceBorder.opacity(0.30))
                            .frame(maxWidth: 190)
                            .frame(height: 14)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .ppPetSurface(
                    radius: PPPetProfileMetrics.cardRadius,
                    tint: Color.ppSurface,
                    elevation: false
                )
                .accessibilityHidden(true)
            }
        }
    }
}

private struct PPPetProfilesStateView: View {
    let isError: Bool
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isError ? "arrow.triangle.2.circlepath" : "pawprint.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isError ? Color.ppWarning : Color.ppPrimary)
                .frame(width: 64, height: 64)
                .background(
                    (isError ? Color.ppWarning : Color.ppPrimary).opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            Text(PPPetLang(isError ? "pet_profiles_error_title" : "pet_profiles_empty_title"))
                .font(PPPetProfileFont.title())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)

            Text(PPPetLang(isError ? "pet_profiles_error_subtitle" : "pet_profiles_empty_subtitle"))
                .font(PPPetProfileFont.body())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAction) {
                Label(
                    PPPetLang(isError ? "Retry" : "pet_add_title"),
                    systemImage: isError ? "arrow.clockwise" : "plus"
                )
            }
            .buttonStyle(PPPetProfilePrimaryButtonStyle())
            .frame(maxWidth: 260)
            .accessibilityLabel(PPPetLang(isError ? "Retry" : "pet_add_title"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .ppPetSurface(radius: 28, tint: Color.ppSurfaceRaised, elevation: false)
    }
}

private struct PPPetProfileAvatar: View {
    let pet: PPPetProfile
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.ppSoftRose.opacity(0.65))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.30, weight: .medium))
                    .foregroundStyle(Color.ppPrimary.opacity(0.72))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(Color.ppPrimary.opacity(0.16), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

private struct PPPetProfilesCarePassport: View {
    let pet: PPPetProfile
    let image: UIImage?
    let profileCount: Int
    let vaccinationCount: Int
    let onSelect: () -> Void
    let onAdd: () -> Void
    let onReminders: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var vaccinationText: String {
        PPPetCountText(
            "pet_profiles_vaccine_count_format",
            count: pet.vaccinations.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            passportHeader
            identity
            careLedger
            actionRail
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.ppSurfaceRaised)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Color.ppPrimary)
                .frame(width: contrast == .increased ? 6 : 4, height: 74)
                .padding(.leading, 1)
                .accessibilityHidden(true)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.58)
                        : Color.ppPrimary.opacity(0.22),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
        )
        .shadow(
            color: contrast == .increased ? .clear : Color.black.opacity(0.075),
            radius: 22,
            x: 0,
            y: 10
        )
        .contextMenu {
            Button(action: onSelect) {
                Label(PPPetLang("Edit"), systemImage: "pencil")
            }
            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash.fill")
            }

            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star.fill")
                }
                .tint(.ppPremiumAccent)
            }
        }
    }

    private var passportHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PPPetLang("pet_profiles_manage"))
                    .font(PPPetProfileFont.caption())
                    .foregroundStyle(Color.ppPrimary)
                    .textCase(.uppercase)
                Text(PPPetLang("pet_profiles_title"))
                    .font(PPPetProfileFont.footnote())
                    .foregroundStyle(Color.ppTextSecondary)
            }

            Spacer(minLength: 8)

            if pet.isDefaultPet {
                Label(
                    PPPetLang("pet_profiles_default_badge"),
                    systemImage: "star.fill"
                )
                .font(PPPetProfileFont.caption())
                .foregroundStyle(Color.ppPremiumAccent)
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .background(
                    Color.ppPremiumAccent.opacity(0.14),
                    in: Capsule()
                )
            }

            Menu {
                Button(action: onSelect) {
                    Label(PPPetLang("Edit"), systemImage: "pencil")
                }
                if !pet.isDefaultPet {
                    Button(action: onMakeDefault) {
                        Label(PPPetLang("pet_default_action"), systemImage: "star")
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Label(PPPetLang("Delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.ppSecondarySurface, in: Circle())
            }
            .accessibilityLabel(PPPetLang("Edit"))
        }
    }

    @ViewBuilder
    private var identity: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                passportPortrait
                identityCopy
            }
        } else {
            HStack(alignment: .center, spacing: 18) {
                passportPortrait
                identityCopy
            }
        }
    }

    private var passportPortrait: some View {
        ZStack(alignment: .bottomTrailing) {
            PPPetProfileAvatar(
                pet: pet,
                image: image,
                size: dynamicTypeSize.isAccessibilitySize ? 132 : 124
            )

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Color.ppCareAccent, in: Circle())
                .overlay(Circle().stroke(Color.ppSurfaceRaised, lineWidth: 3))
                .accessibilityHidden(true)
        }
    }

    private var identityCopy: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                Text(pet.ppDisplayName)
                    .font(PPPetProfileFont.largeTitle())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pet.ppDisplayDetail)
                    .font(PPPetProfileFont.body())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Label(vaccinationText, systemImage: "cross.case.fill")
                    .font(PPPetProfileFont.medium())
                    .foregroundStyle(Color.ppCareAccent)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    Text(PPPetLang("Edit"))
                    Image(systemName: "chevron.forward")
                        .accessibilityHidden(true)
                }
                .font(PPPetProfileFont.caption())
                .foregroundStyle(Color.ppPrimary)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPPetProfilePressStyle())
        .accessibilityLabel(
            "\(pet.ppDisplayName), \(pet.ppDisplayDetail), \(vaccinationText)"
        )
        .accessibilityHint(
            PPPetLang("pet_profiles_card_hint", fallback: "Opens this pet profile")
        )
        .accessibilityAddTraits(pet.isDefaultPet ? .isSelected : [])
        .accessibilityAction(named: PPPetLang("pet_default_action")) {
            guard !pet.isDefaultPet else { return }
            onMakeDefault()
        }
        .accessibilityAction(named: PPPetLang("Delete")) {
            onDelete()
        }
    }

    private var careLedger: some View {
        HStack(spacing: 0) {
            PPPetPassportMetric(
                value: profileCount,
                label: PPPetLang("pet_profiles_profile_count_label"),
                symbol: "pawprint.fill",
                color: .ppPrimary,
                accessibilityLabel: PPPetCountText(
                    "pet_profiles_profile_count_accessibility_format",
                    count: profileCount
                )
            )

            Rectangle()
                .fill(Color.ppSurfaceBorder)
                .frame(width: 1, height: 48)
                .accessibilityHidden(true)

            PPPetPassportMetric(
                value: vaccinationCount,
                label: PPPetLang("pet_profiles_vaccination_count_label"),
                symbol: "cross.case.fill",
                color: .ppCareAccent,
                accessibilityLabel: PPPetCountText(
                    "pet_profiles_vaccine_count_format",
                    count: vaccinationCount
                )
            )
        }
        .padding(.vertical, 12)
        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var actionRail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                passportAction(
                    title: PPPetLang("pet_add_title"),
                    symbol: "plus",
                    filled: true,
                    action: onAdd
                )
                passportAction(
                    title: PPPetLang("pet_reminders_tab"),
                    symbol: "bell.fill",
                    filled: false,
                    action: onReminders
                )
            }
        } else {
            HStack(spacing: 10) {
                passportAction(
                    title: PPPetLang("pet_add_title"),
                    symbol: "plus",
                    filled: true,
                    action: onAdd
                )
                passportAction(
                    title: PPPetLang("pet_reminders_tab"),
                    symbol: "bell.fill",
                    filled: false,
                    action: onReminders
                )
            }
        }
    }

    private func passportAction(
        title: String,
        symbol: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(PPPetProfileFont.medium())
                .foregroundStyle(filled ? Color.white : Color.ppPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, 12)
                .background(
                    filled ? Color.ppPrimary : Color.ppSoftRose,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            filled ? Color.clear : Color.ppPrimary.opacity(0.18),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PPPetProfilePressStyle())
    }
}

private struct PPPetPassportMetric: View {
    let value: Int
    let label: String
    let symbol: String
    let color: Color
    let accessibilityLabel: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(PPPetProfileFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(label)
                    .font(PPPetProfileFont.footnote())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PPPetProfilesRosterHeading: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(PPPetLang("pet_profiles_manage"))
                    .font(PPPetProfileFont.title())
                    .foregroundStyle(Color.ppTextPrimary)

                Text("\(count)")
                    .font(PPPetProfileFont.caption())
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minWidth: 32, minHeight: 28)
                    .background(Color.ppSoftRose, in: Circle())
                    .accessibilityHidden(true)
            }

            Text(PPPetLang("pet_profiles_section_subtitle"))
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            PPPetCountText(
                "pet_profiles_profile_count_accessibility_format",
                count: count
            )
        )
    }
}

private struct PPPetProfileCard: View {
    let pet: PPPetProfile
    let image: UIImage?
    let onSelect: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var vaccinationText: String {
        PPPetCountText("pet_profiles_vaccine_count_format", count: pet.vaccinations.count)
    }

    private var cardAccessibilityLabel: String {
        let defaultPart = pet.isDefaultPet ? ", \(PPPetLang("pet_profiles_default_badge"))" : ""
        return "\(pet.ppDisplayName), \(pet.ppDisplayDetail), \(vaccinationText)\(defaultPart)"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 14) {
                PPPetProfileAvatar(pet: pet, image: image, size: 78)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pet.ppDisplayName)
                            .font(PPPetProfileFont.headline())
                            .foregroundStyle(Color.ppTextPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if pet.isDefaultPet {
                            Label(PPPetLang("pet_profiles_default_badge"), systemImage: "star.fill")
                                .font(PPPetProfileFont.caption())
                                .foregroundStyle(Color.ppPremiumAccent)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.ppPremiumAccent.opacity(0.15), in: Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(pet.ppDisplayDetail)
                        .font(PPPetProfileFont.medium())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 7) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(vaccinationText)
                            .font(PPPetProfileFont.footnote())
                            .lineLimit(2)
                    }
                    .foregroundStyle(Color.ppCareAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.ppCareAccent.opacity(0.11), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ppTextSecondary.opacity(0.72))
                    .frame(width: PPPetProfileMetrics.minimumHitSize, height: PPPetProfileMetrics.minimumHitSize)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .contentShape(RoundedRectangle(cornerRadius: PPPetProfileMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(PPPetProfilePressStyle())
        .modifier(PPPetProfileCardSurface(isDefault: pet.isDefaultPet))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash.fill")
            }

            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star.fill")
                }
                .tint(.ppPremiumAccent)
            }
        }
        .contextMenu {
            Button(action: onSelect) {
                Label(PPPetLang("Edit"), systemImage: "pencil")
            }
            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(PPPetLang("pet_profiles_card_hint", fallback: "Opens this pet profile"))
        .accessibilityAddTraits(pet.isDefaultPet ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(named: PPPetLang("pet_default_action")) {
            guard !pet.isDefaultPet else { return }
            onMakeDefault()
        }
        .accessibilityAction(named: PPPetLang("Delete")) {
            onDelete()
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84), value: pet.isDefaultPet)
    }
}

private struct PPPetProfileCardSurface: ViewModifier {
    let isDefault: Bool

    func body(content: Content) -> some View {
        if isDefault {
            content
                .ppPetGlass(radius: PPPetProfileMetrics.cardRadius, tint: .ppPremiumAccent.opacity(0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: PPPetProfileMetrics.cardRadius, style: .continuous)
                        .stroke(Color.ppPremiumAccent.opacity(0.30), lineWidth: 1)
                )
        } else {
            content.ppPetSurface(radius: PPPetProfileMetrics.cardRadius, tint: .ppSurface, elevation: true)
        }
    }
}

// MARK: - List screen

struct PPPetProfilesListScreen: View {
    @ObservedObject var store: PPPetProfilesListStore

    let onBack: () -> Void
    let onAdd: () -> Void
    let onReminders: () -> Void
    let onRefresh: () -> Void
    let onSelect: (PPPetProfile) -> Void
    let onMakeDefault: (PPPetProfile) -> Void
    let onDelete: (PPPetProfile) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var vaccinationCount: Int {
        store.pets.reduce(0) { $0 + $1.vaccinations.count }
    }

    private var featuredPet: PPPetProfile? {
        store.pets.first(where: \.isDefaultPet) ?? store.pets.first
    }

    private var rosterPets: [PPPetProfile] {
        guard let featuredPet else { return store.pets }
        return store.pets.filter {
            $0.ppStableIdentifier != featuredPet.ppStableIdentifier
        }
    }

    private var usesRegularLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        PPPetProfileCanvas {
            VStack(spacing: 0) {
                PPPetProfileNavigationHeader(
                    title: PPPetLang("pet_profiles_title"),
                    onBack: onBack,
                    trailing: AnyView(
                        HStack(spacing: 3) {
                            PPPetProfileIconButton(
                                systemName: "bell",
                                accessibilityLabel: PPPetLang("pet_reminders_tab"),
                                tint: .ppPrimary,
                                action: onReminders
                            )
                            PPPetProfileIconButton(
                                systemName: "plus",
                                accessibilityLabel: PPPetLang("pet_add_title"),
                                tint: .ppPrimary,
                                action: onAdd
                            )
                        }
                    )
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.isLoading {
                            PPPetProfilesLoadingState()
                        } else if store.hasError {
                            PPPetProfilesStateView(isError: true, onAction: onRefresh)
                        } else if store.pets.isEmpty {
                            PPPetProfilesStateView(isError: false, onAction: onAdd)
                        } else {
                            populatedContent
                        }
                    }
                    .frame(
                        maxWidth: usesRegularLayout
                            ? 1120
                            : PPPetProfileMetrics.contentMaxWidth
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, PPPetProfileMetrics.screenMargin)
                    .padding(.top, 18)
                    .padding(.bottom, 84)
                }
                .refreshable {
                    onRefresh()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA"))
    }

    @ViewBuilder
    private var populatedContent: some View {
        if usesRegularLayout, let featuredPet {
            HStack(alignment: .top, spacing: 24) {
                passport(for: featuredPet)
                    .frame(maxWidth: 480)

                roster
                    .frame(maxWidth: .infinity)
            }
        } else if let featuredPet {
            VStack(alignment: .leading, spacing: 28) {
                passport(for: featuredPet)
                roster
            }
        }
    }

    private func passport(for pet: PPPetProfile) -> some View {
        PPPetProfilesCarePassport(
            pet: pet,
            image: image(for: pet),
            profileCount: store.pets.count,
            vaccinationCount: vaccinationCount,
            onSelect: { onSelect(pet) },
            onAdd: onAdd,
            onReminders: onReminders,
            onMakeDefault: { onMakeDefault(pet) },
            onDelete: { onDelete(pet) }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
    }

    @ViewBuilder
    private var roster: some View {
        if !rosterPets.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                PPPetProfilesRosterHeading(count: rosterPets.count)

                LazyVStack(spacing: 12) {
                    ForEach(rosterPets, id: \.ppStableIdentifier) { pet in
                        PPPetProfileCard(
                            pet: pet,
                            image: image(for: pet),
                            onSelect: { onSelect(pet) },
                            onMakeDefault: { onMakeDefault(pet) },
                            onDelete: { onDelete(pet) }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
            }
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.34, dampingFraction: 0.88),
                value: store.pets.map(\.ppStableIdentifier)
            )
        }
    }

    private func image(for pet: PPPetProfile) -> UIImage? {
        store.images[pet.ppStableIdentifier] ?? store.images[pet.petID]
    }
}
