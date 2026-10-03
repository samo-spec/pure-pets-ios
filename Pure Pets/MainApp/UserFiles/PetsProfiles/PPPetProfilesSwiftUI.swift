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

// MARK: - Pet folio

/// List-only components. The shared editor primitives above keep their existing contract.
private struct PPPetFolioPortrait: View {
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        ZStack {
            Color.ppSecondarySurface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: size * 0.28, weight: .medium))
                    .foregroundStyle(Color.ppPrimary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct PPPetFolioDefaultMark: View {
    var body: some View {
        Label(PPPetLang("pet_profiles_default_badge"), systemImage: "star.fill")
            .font(PPPetProfileFont.caption())
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.ppSecondarySurface, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PPPetFolioMenu: View {
    let pet: PPPetProfile
    let onEdit: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(action: onEdit) {
                Label(PPPetLang("pet_folio_edit_profile"), systemImage: "pencil")
            }
            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star")
                }
                .disabled(pet.petID.isEmpty)
            }
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash")
            }
            .disabled(pet.petID.isEmpty)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 48, height: 48)
                .background(Color.ppSecondarySurface, in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel(String(format: PPPetLang("pet_folio_actions_format"), pet.ppDisplayName))
    }
}

private struct PPPetFolioRecord: View {
    let pet: PPPetProfile
    let image: UIImage?
    let availableWidth: CGFloat
    let onEdit: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var stacksIdentity: Bool {
        dynamicTypeSize.isAccessibilitySize || availableWidth < 340
    }

    private var usesSpread: Bool {
        availableWidth >= 860 && !dynamicTypeSize.isAccessibilitySize
    }

    private var portraitSize: CGFloat {
        usesSpread ? 260 : (stacksIdentity ? 144 : min(196, max(120, availableWidth * 0.36)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                if pet.isDefaultPet {
                    PPPetFolioDefaultMark()
                } else {
                    Text(PPPetLang("pet_folio_profile"))
                        .font(PPPetProfileFont.medium())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                Spacer(minLength: 0)
                PPPetFolioMenu(pet: pet, onEdit: onEdit, onMakeDefault: onMakeDefault, onDelete: onDelete)
            }

            if usesSpread {
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 24) {
                        portrait
                        identity
                    }
                    .frame(width: 300, alignment: .leading)
                    VStack(alignment: .leading, spacing: 28) {
                        vaccinationRecord
                        editButton
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            } else {
                compactRecord
            }
        }
        .padding(availableWidth < 360 ? 20 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.ppTextSecondary : Color.ppSurfaceBorder,
                              lineWidth: contrast == .increased ? 1.5 : 0.75)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    private var compactRecord: some View {
        VStack(alignment: .leading, spacing: 24) {
            if stacksIdentity {
                VStack(alignment: .leading, spacing: 20) {
                    portrait
                    identity
                }
            } else {
                HStack(alignment: .center, spacing: 20) {
                    portrait
                    identity
                }
            }

            Rectangle()
                .fill(contrast == .increased ? Color.ppTextSecondary : Color.ppSurfaceBorder)
                .frame(height: 1)
                .accessibilityHidden(true)

            vaccinationRecord
            editButton
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Text(PPPetLang("pet_folio_edit_profile"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "pencil")
                    .accessibilityHidden(true)
            }
            .font(PPPetProfileFont.headline())
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 54)
            .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PPPetProfilePressStyle())
        .accessibilityHint(PPPetLang("pet_folio_edit_hint"))
    }

    private var portrait: some View {
        Button(action: onEdit) {
            PPPetFolioPortrait(image: image, size: portraitSize)
        }
        .buttonStyle(PPPetProfilePressStyle())
        .accessibilityLabel(String(format: PPPetLang("pet_profiles_image_accessibility_format"), pet.ppDisplayName))
        .accessibilityHint(PPPetLang("pet_folio_edit_hint"))
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(pet.ppDisplayName)
                .font(PPPetProfileFont.largeTitle())
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 10) {
                identityField(PPPetLang("pet_folio_breed"), value: pet.ppDisplayBreed)
                identityField(PPPetLang("pet_folio_age"), value: pet.displayAgeText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func identityField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(PPPetProfileFont.caption())
                .foregroundStyle(Color.ppTextSecondary)
            Text(value)
                .font(PPPetProfileFont.body())
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var vaccinationRecord: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(PPPetLang("pet_folio_care_title"))
                    .font(PPPetProfileFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image(systemName: "cross.case")
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(PPPetCountText("pet_profiles_vaccine_count_format", count: pet.vaccinations.count))
                    .font(PPPetProfileFont.medium())
                    .foregroundStyle(Color.ppTextPrimary)
                if pet.vaccinations.isEmpty {
                    Text(PPPetLang("pet_folio_vaccines_empty"))
                        .font(PPPetProfileFont.body())
                        .foregroundStyle(Color.ppTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            // A read-only preview, not a second route pretending to open a vaccine screen.
            // The existing editor remains the owner of every vaccination mutation.
            ForEach(Array(pet.vaccinations.prefix(3).enumerated()), id: \.offset) { _, record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name.isEmpty ? PPPetLang("pet_vaccine_name") : record.name)
                        .font(PPPetProfileFont.body())
                        .foregroundStyle(Color.ppTextPrimary)
                    if let date = record.nextDueDate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PPPetLang("pet_vaccine_next_due"))
                            Text(date, style: .date)
                        }
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(contrast == .increased ? Color.ppTextPrimary : Color.ppCareAccent)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
            if pet.vaccinations.count > 3 {
                Text(PPPetCountText("pet_folio_more_records_format", count: pet.vaccinations.count - 3))
                    .font(PPPetProfileFont.footnote())
                    .foregroundStyle(Color.ppTextSecondary)
            }
            Text(PPPetLang("pet_folio_vaccines_detail"))
                .font(PPPetProfileFont.footnote())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
    }
}

private struct PPPetFolioSelector: View {
    let pet: PPPetProfile
    let image: UIImage?
    let isSelected: Bool
    let isVertical: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                PPPetFolioPortrait(image: image, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.ppDisplayName)
                        .font(PPPetProfileFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if pet.isDefaultPet {
                        Label(PPPetLang("pet_profiles_default_badge"), systemImage: "star.fill")
                            .font(PPPetProfileFont.caption())
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
                if isVertical { Spacer(minLength: 0) }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(contrast == .increased ? Color.ppTextPrimary : Color.ppPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(maxWidth: isVertical ? .infinity : nil, alignment: .leading)
            .background(isSelected ? Color.ppSurface : Color.clear,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? (contrast == .increased ? Color.ppTextPrimary : Color.ppPrimary) : Color.ppSurfaceBorder,
                                  lineWidth: isSelected ? 1.5 : 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PPPetProfilePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: PPPetLang("pet_folio_select_format"), pet.ppDisplayName))
        .accessibilityValue(pet.isDefaultPet ? PPPetLang("pet_profiles_default_badge") : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: PPPetLang("pet_folio_edit_profile"), onEdit)
        .accessibilityAction(named: PPPetLang("Delete"), onDelete)
        .contextMenu {
            Button(action: onEdit) {
                Label(PPPetLang("pet_folio_edit_profile"), systemImage: "pencil")
            }
            if !pet.isDefaultPet {
                Button(action: onMakeDefault) {
                    Label(PPPetLang("pet_default_action"), systemImage: "star")
                }
                .disabled(pet.petID.isEmpty)
            }
            Button(role: .destructive, action: onDelete) {
                Label(PPPetLang("Delete"), systemImage: "trash")
            }
            .disabled(pet.petID.isEmpty)
        }
    }
}

private struct PPPetFolioState: View {
    let isLoading: Bool
    let isError: Bool
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if isLoading {
                ProgressView()
                    .tint(.ppPrimary)
                    .accessibilityLabel(PPPetLang("Loading"))
                Text(PPPetLang("Loading"))
                    .font(PPPetProfileFont.title())
                    .foregroundStyle(Color.ppTextPrimary)
                HStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.ppSurfaceBorder)
                        .frame(width: 112, height: 144)
                    VStack(alignment: .leading, spacing: 16) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.ppSurfaceBorder).frame(height: 24)
                        RoundedRectangle(cornerRadius: 4).fill(Color.ppSurfaceBorder).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.ppSurfaceBorder).frame(width: 64, height: 12)
                    }
                }
                .accessibilityHidden(true)
            } else {
                Image(systemName: isError ? "arrow.clockwise" : "pawprint.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 88, height: 88)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .accessibilityHidden(true)
                Text(PPPetLang(isError ? "pet_profiles_error_title" : "pet_folio_empty_title"))
                    .font(PPPetProfileFont.largeTitle())
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(PPPetLang(isError ? "pet_profiles_error_subtitle" : "pet_folio_empty_detail"))
                    .font(PPPetProfileFont.body())
                    .foregroundStyle(Color.ppTextSecondary)
                Button(action: onAction) {
                    Label(PPPetLang(isError ? "Retry" : "pet_profiles_add_first"),
                          systemImage: isError ? "arrow.clockwise" : "plus")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(PPPetProfilePrimaryButtonStyle())
                .frame(maxWidth: 340)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - List screen

struct PPPetProfilesListScreen: View {
    @ObservedObject var store: PPPetProfilesListStore

    let onBack: () -> Void
    let onAdd: () -> Void
    let onReminders: () -> Void
    let onRefresh: () async -> Void
    let onSelect: (PPPetProfile) -> Void
    let onMakeDefault: (PPPetProfile) -> Void
    let onDelete: (PPPetProfile) -> Void

    // Selection is a local browsing choice, never an optimistic default-pet write.
    @State private var selectedID: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selectedPet: PPPetProfile? {
        if let selectedID, let pet = store.pets.first(where: { $0.ppStableIdentifier == selectedID }) {
            return pet
        }
        return store.pets.first(where: \.isDefaultPet) ?? store.pets.first
    }

    private var vaccinationCount: Int { store.pets.reduce(0) { $0 + $1.vaccinations.count } }

    var body: some View {
        GeometryReader { geometry in
            let margin: CGFloat = geometry.size.width >= 600 ? 32 : 20
            let contentWidth = max(0, min(1120, geometry.size.width - margin * 2))
            let sidebar = contentWidth >= 820 && !dynamicTypeSize.isAccessibilitySize && store.pets.count > 1

            VStack(spacing: 0) {
                navigation
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        introduction
                        if store.isLoading && store.pets.isEmpty {
                            PPPetFolioState(isLoading: true, isError: false, onAction: requestRefresh)
                        } else if store.hasError && store.pets.isEmpty {
                            PPPetFolioState(isLoading: false, isError: true, onAction: requestRefresh)
                        } else if store.pets.isEmpty {
                            PPPetFolioState(isLoading: false, isError: false, onAction: onAdd)
                        } else if let pet = selectedPet {
                            if sidebar {
                                HStack(alignment: .top, spacing: 32) {
                                    VStack(alignment: .leading, spacing: 24) {
                                        roster(vertical: true)
                                        reminders
                                    }
                                    .frame(width: 240)
                                    folio(for: pet, width: contentWidth - 272)
                                }
                            } else {
                                if store.pets.count > 1 { roster(vertical: dynamicTypeSize.isAccessibilitySize) }
                                folio(for: pet, width: contentWidth)
                                reminders
                            }
                            totals
                        }
                    }
                    .frame(maxWidth: contentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, margin)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .refreshable { await onRefresh() }
            }
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA"))
        .onAppear { retainSelection() }
        .onChange(of: store.pets.map(\.ppStableIdentifier)) { _ in retainSelection() }
    }

    private var navigation: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .accessibilityLabel(PPPetLang("Back"))

            Spacer(minLength: 0)

            Menu {
                Button(action: requestRefresh) {
                    Label(PPPetLang("pet_profiles_refresh_accessibility"), systemImage: "arrow.clockwise")
                }
                Button(action: onReminders) {
                    Label(PPPetLang("pet_reminders_tab"), systemImage: "bell")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .accessibilityLabel(PPPetLang("pet_profiles_manage"))

            Button(action: onAdd) {
                Label(PPPetLang("pet_add_title"), systemImage: "plus")
                    .font(PPPetProfileFont.medium())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minHeight: 48)
                    .background(Color.ppSecondarySurface, in: Capsule())
            }
        }
        .buttonStyle(PPPetProfilePressStyle())
        .foregroundStyle(Color.ppTextPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.ppBackground)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(PPPetLang("pet_folio_title"))
                .font(.custom("Beiruti-Bold", size: 38, relativeTo: .largeTitle))
                .foregroundStyle(Color.ppTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(PPPetLang("pet_folio_subtitle"))
                .font(PPPetProfileFont.body())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func folio(for pet: PPPetProfile, width: CGFloat) -> some View {
        PPPetFolioRecord(
            pet: pet, image: store.images[pet.ppStableIdentifier], availableWidth: width,
            onEdit: { onSelect(pet) }, onMakeDefault: { onMakeDefault(pet) }, onDelete: { onDelete(pet) }
        )
    }

    private func roster(vertical: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PPPetLang("pet_folio_all_pets"))
                .font(PPPetProfileFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
                .accessibilityAddTraits(.isHeader)
            if vertical {
                LazyVStack(spacing: 10) {
                    ForEach(store.pets, id: \.ppStableIdentifier) { pet in selector(for: pet, vertical: true) }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(store.pets, id: \.ppStableIdentifier) { pet in
                            selector(for: pet, vertical: false).frame(width: 208)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func selector(for pet: PPPetProfile, vertical: Bool) -> some View {
        PPPetFolioSelector(
            pet: pet, image: store.images[pet.ppStableIdentifier],
            isSelected: selectedPet?.ppStableIdentifier == pet.ppStableIdentifier, isVertical: vertical,
            onSelect: { selectedID = pet.ppStableIdentifier },
            onEdit: { onSelect(pet) }, onMakeDefault: { onMakeDefault(pet) }, onDelete: { onDelete(pet) }
        )
    }

    private var reminders: some View {
        Button(action: onReminders) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "bell")
                    .font(.system(size: 23, weight: .regular))
                    .frame(width: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(PPPetLang("pet_reminders_tab"))
                        .font(PPPetProfileFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(PPPetLang("pet_folio_reminders_detail"))
                        .font(PPPetProfileFont.footnote())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PPPetProfilePressStyle())
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PPPetCountText("pet_profiles_profile_count_accessibility_format", count: store.pets.count))
            Text(PPPetCountText("pet_profiles_vaccine_count_format", count: vaccinationCount))
        }
        .font(PPPetProfileFont.footnote())
        .foregroundStyle(Color.ppTextSecondary)
        .accessibilityElement(children: .combine)
    }

    private func retainSelection() {
        selectedID = selectedPet?.ppStableIdentifier
    }

    private func requestRefresh() {
        Task { await onRefresh() }
    }
}
