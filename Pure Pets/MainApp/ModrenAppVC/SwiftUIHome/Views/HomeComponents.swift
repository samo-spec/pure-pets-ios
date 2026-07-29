import SwiftUI
import UIKit

/// Home-scoped Beiruti typography that participates in Dynamic Type without
/// changing typography behavior on unrelated legacy surfaces.
enum HomeFont {
    static func title1() -> Font {
        .custom("Beiruti-Bold", size: 28, relativeTo: .title)
    }

    static func title2() -> Font {
        .custom("Beiruti-Bold", size: 22, relativeTo: .title2)
    }

    static func headline() -> Font {
        .custom("Beiruti-Bold", size: 17, relativeTo: .headline)
    }

    static func callout() -> Font {
        .custom("Beiruti-Regular", size: 16, relativeTo: .callout)
    }

    static func subheadline() -> Font {
        .custom("Beiruti-Regular", size: 15, relativeTo: .subheadline)
    }

    static func footnote() -> Font {
        .custom("Beiruti-Regular", size: 13, relativeTo: .footnote)
    }

    static func caption1() -> Font {
        .custom("Beiruti-Regular", size: 12, relativeTo: .caption)
    }

    static func caption2() -> Font {
        .custom("Beiruti-Regular", size: 11, relativeTo: .caption2)
    }

    static func bold(_ size: CGFloat) -> Font {
        .custom(
            "Beiruti-Bold",
            size: size,
            relativeTo: relativeStyle(for: size)
        )
    }

    static func medium(_ size: CGFloat) -> Font {
        .custom(
            "Beiruti-Medium",
            size: size,
            relativeTo: relativeStyle(for: size)
        )
    }

    private static func relativeStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...11: return .caption2
        case ...12: return .caption
        case ...13: return .footnote
        case ...15: return .subheadline
        case ...17: return .body
        case ...20: return .title3
        default: return .title2
        }
    }
}

struct HomeCommandBar: View {
    let state: HomeViewState
    let searchAction: () -> Void
    let cartAction: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            searchButton
            cartButton
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.sm)
        .background(alignment: .bottom) {
            HomeTopFadeBackdrop(contrast: contrast)
                .frame(height: 168)
                .ignoresSafeArea(edges: .top)
        }
        .environment(
            \.layoutDirection,
            state.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var searchButton: some View {
        Button(action: searchAction) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                Text(
                    HomeModelAdapter.localized(
                        "home_pulse_search_prompt",
                        fallback: "Search products, pets, and services"
                    )
                )
                .font(HomeFont.callout())
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Color.ppSurface.opacity(contrast == .increased ? 1 : 0.86),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder,
                    lineWidth: contrast == .increased ? 1.4 : 0.7
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_search_a11y",
                fallback: "Search Pure Pets"
            )
        )
    }

    private var cartButton: some View {
        Button(action: cartAction) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 48, height: 48)
                    .background(Color.ppSurface.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(Color.ppBorder, lineWidth: 0.7))

                if state.cartCount > 0 {
                    Text(state.cartCount > 99 ? "99+" : "\(state.cartCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, state.cartCount > 9 ? 5 : 0)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.ppPrimary, in: Capsule())
                        .overlay(Capsule().stroke(Color.ppSurface, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_cart_a11y",
                fallback: "Cart"
            )
        )
        .accessibilityValue(
            String(
                format: HomeModelAdapter.localized(
                    "home_pulse_cart_count_a11y",
                    fallback: "%d items"
                ),
                state.cartCount
            )
        )
    }
}

private struct HomeTopFadeBackdrop: View {
    let contrast: ColorSchemeContrast

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            LinearGradient(
                stops: [
                    .init(
                        color: Color.ppBackground.opacity(
                            contrast == .increased ? 0.96 : 0.78
                        ),
                        location: 0
                    ),
                    .init(
                        color: Color.ppBackground.opacity(
                            contrast == .increased ? 0.82 : 0.42
                        ),
                        location: 0.70
                    ),
                    .init(color: Color.clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.82),
                    .init(color: .black.opacity(0.76), location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HomeLocationContextButton: View {
    let state: HomeViewState
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: locationSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.ppPrimary.opacity(0.10), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        HomeModelAdapter.localized(
                            "home_pulse_location_label",
                            fallback: "Area"
                        )
                    )
                    .font(HomeFont.caption2())
                    .foregroundStyle(Color.ppTextSecondary)

                    Text(locationTitle)
                        .font(HomeFont.medium(14))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(2)
                }

                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, PPSpace.xs)
            .frame(minHeight: 48)
            .background(
                Color.ppSurface.opacity(contrast == .increased ? 1 : 0.82),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder,
                    lineWidth: contrast == .increased ? 1.4 : 0.7
                )
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                HomeModelAdapter.localized(
                    "home_pulse_location_label",
                    fallback: "Area"
                ),
                locationTitle,
            ].joined(separator: ", ")
        )
        .environment(
            \.layoutDirection,
            state.isRightToLeft ? .rightToLeft : .leftToRight
        )
    }

    private var locationTitle: String {
        if !state.location.areaName.isEmpty {
            return state.location.areaName
        }
        switch state.location.presentation {
        case .loading:
            return HomeModelAdapter.localized(
                "home_pulse_location_loading",
                fallback: "Locating…"
            )
        case .denied, .restricted:
            return HomeModelAdapter.localized(
                "home_pulse_location_denied",
                fallback: "Choose manually"
            )
        case .failed:
            return HomeModelAdapter.localized(
                "home_pulse_location_failed",
                fallback: "Location unavailable"
            )
        case .notDetermined, .ready:
            return HomeModelAdapter.localized(
                "home_pulse_choose_area",
                fallback: "Choose area"
            )
        }
    }

    private var locationSymbol: String {
        switch state.location.presentation {
        case .loading: return "location.circle"
        case .denied, .restricted: return "location.slash.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .notDetermined, .ready:
            return state.location.isManual ? "mappin.circle.fill" : "location.fill"
        }
    }
}

struct HomeMyPetProfileCard: View {
    let pets: [HomePetModel]
    let selectedID: String?
    let isLoading: Bool
    let errorMessage: String?
    let action: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            cardBody
        }
        .buttonStyle(HomeMyPetProfileCardPressStyle())
        .disabled(isLoading)
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private var cardBody: some View {
        ZStack {
            cardShape
                .fill(cardGradient)
                .overlay {
                    decorativeLayer
                }
                .overlay {
                    cardShape.strokeBorder(
                        borderColor,
                        lineWidth: contrast == .increased ? 1.3 : 0.7
                    )
                }
                .shadow(
                    color: shadowColor,
                    radius: colorScheme == .dark ? 0 : 24,
                    x: 0,
                    y: colorScheme == .dark ? 0 : 18
                )

            contentLayer
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardHeight)
        .contentShape(cardShape)
        .overlay {
            if isFocused {
                cardShape.strokeBorder(
                    Color.ppPrimary,
                    lineWidth: contrast == .increased ? 3 : 2.4
                )
            }
        }
    }

    private var decorativeLayer: some View {
        ZStack {
            Circle()
                .fill(orbColor)
                .frame(width: 108, height: 108)
                .offset(
                    x: layoutDirection == .rightToLeft ? -28 : 28,
                    y: -26
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .topTrailing)

            Circle()
                .fill(
                    Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28)
                )
                .frame(width: 36, height: 36)
                .padding(.leading, 18)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottomLeading)
        }
        .accessibilityHidden(true)
    }

    private var contentLayer: some View {
        ZStack(alignment: .topTrailing) {
            avatar
                .padding(.top, 18)
                .padding(.trailing, 18)

            VStack(alignment: .leading, spacing: 0) {
                topCopy
                    .padding(.trailing, avatarTextClearance)

                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 16 : 12)

                metaStack

                ctaView
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 14 : 12)
            }
            .padding(.top, 18)
            .padding(.leading, 18)
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
    }

    private var topCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(HomeFont.bold(11))
                .foregroundStyle(eyebrowTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .frame(minHeight: 28)
                .background(
                    Color.white.opacity(
                        colorScheme == .dark ? 0.24 : 0.72
                    ),
                    in: Capsule()
                )
                .padding(.bottom, 6)

            Text(title)
                .font(HomeFont.bold(24))
                .foregroundStyle(primaryTextColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.84)
                .allowsTightening(true)
                .frame(minHeight: 30, alignment: .leading)
                .padding(.leading, -6)
                .padding(.bottom, 8)

            Text(subtitle)
                .font(HomeFont.medium(13))
                .foregroundStyle(subtitleTextColor)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.leading, -6)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18)
                )
                .overlay {
                    Circle().strokeBorder(
                        Color.white.opacity(
                            colorScheme == .dark ? 0.10 : 0.24
                        ),
                        lineWidth: 1
                    )
                }
                .shadow(
                    color: Color.black.opacity(
                        colorScheme == .dark ? 0 : 0.10
                    ),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .frame(width: 82, height: 82)

            avatarContent
                .frame(width: 68, height: 68)
                .background(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12),
                    in: Circle()
                )
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(
                        Color.white.opacity(0.35),
                        lineWidth: 1.5
                    )
                }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let pet = defaultPet,
           let imageURL = pet.imageURL,
           !imageURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HomeRemoteImage(
                urlString: imageURL,
                placeholder: UIImage(named: "petcare_placeholder"),
                contentMode: .scaleAspectFill
            )
        } else if let pet = defaultPet {
            HomeGeneratedPetAvatar(
                name: petDisplayName(pet),
                accent: Color.ppPrimary
            )
        } else {
            Image(systemName: avatarSymbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.ppPrimary.opacity(0.86))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var metaStack: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    metaPill(metaPrimary, emphasized: true)
                    metaPill(metaSecondary, emphasized: false)
                }
            } else {
                HStack(spacing: 8) {
                    metaPill(metaPrimary, emphasized: true)
                    metaPill(metaSecondary, emphasized: false)
                }
            }
        }
        .padding(.leading, -6)
    }

    private func metaPill(
        _ text: String,
        emphasized: Bool
    ) -> some View {
        Text(text)
            .font(HomeFont.medium(11))
            .foregroundStyle(tagTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Color.white.opacity(
                    colorScheme == .dark
                        ? (emphasized ? 0.16 : 0.14)
                        : (emphasized ? 0.54 : 0.46)
                ),
                in: Capsule()
            )
    }

    private var ctaView: some View {
        HStack(spacing: 10) {
            Text(ctaTitle)
                .font(HomeFont.bold(13))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: PPSpace.sm)

            Image(systemName: forwardSymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(primaryTextColor)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 44,
            alignment: .center
        )
        .background(
            Color.white.opacity(colorScheme == .dark ? 0.16 : 0.26),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24),
                    lineWidth: 1
                )
        }
        .padding(.leading, -6)
    }

    private var defaultPet: HomePetModel? {
        pets.first(where: { $0.isDefault })
    }

    private var hasProfilesWithoutDefault: Bool {
        !pets.isEmpty && defaultPet == nil
    }

    private var selectedPet: HomePetModel? {
        if let selectedID,
           let pet = pets.first(where: { $0.id == selectedID }) {
            return pet
        }
        return pets.first
    }

    private var eyebrow: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "home_pulse_loading_title",
                fallback: "Loading"
            )
        }

        if errorMessage != nil {
            return HomeModelAdapter.localized(
                "pet_profiles_title",
                fallback: "Pet Profiles"
            )
        }

        if let pet = defaultPet, pet.isDefault {
            return HomeModelAdapter.localized(
                "pet_default_action",
                fallback: "Default pet"
            )
        }

        return HomeModelAdapter.localized(
            "pet_profiles_title",
            fallback: "Pet Profiles"
        )
    }

    private var title: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "pet_profiles_title",
                fallback: "Pet Profiles"
            )
        }

        if errorMessage != nil {
            return HomeModelAdapter.localized(
                "pet_profiles_error_title",
                fallback: "Couldn't load pet profiles"
            )
        }

        if let pet = defaultPet {
            return petDisplayName(pet)
        }

        if hasProfilesWithoutDefault {
            return HomeModelAdapter.localized(
                "home_pet_profile_choose_default_title",
                fallback: "Choose your default pet"
            )
        }

        return HomeModelAdapter.localized(
            "home_pet_profile_empty_title",
            fallback: "Create your pet profile"
        )
    }

    private var subtitle: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "pet_profiles_loading_home_subtitle",
                fallback: "Syncing your companion card and care details for the home feed."
            )
        }

        if let errorMessage {
            return errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
                ? HomeModelAdapter.localized(
                    "pet_profiles_error_subtitle",
                    fallback: "Check your connection and try again."
                )
                : errorMessage
        }

        if let pet = defaultPet {
            let headline = petSummary(for: pet)
            let detail = HomeModelAdapter.localized(
                "home_pet_profile_vaccine_prompt",
                fallback: "Open the profile to update vaccines, notes, and reminders."
            )
            return "\(headline)\n\(detail)"
        }

        if hasProfilesWithoutDefault {
            return HomeModelAdapter.localized(
                "home_pet_profile_choose_default_subtitle",
                fallback: "Pin one companion here for quick home access to care details, vaccines, and reminders."
            )
        }

        return HomeModelAdapter.localized(
            "home_pet_profile_empty_subtitle",
            fallback: "Turn this card into a pet dashboard with breed, vaccines, reminders, and your default companion."
        )
    }

    private var metaPrimary: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "home_pet_profile_meta_syncing",
                fallback: "Live sync"
            )
        }

        if errorMessage != nil {
            return HomeModelAdapter.localized(
                "pet_profiles_refresh_accessibility",
                fallback: "Refresh pet profiles"
            )
        }

        if defaultPet != nil {
            return HomeModelAdapter.localized(
                "home_pet_profile_meta_vaccines",
                fallback: "Vaccines"
            )
        }

        if hasProfilesWithoutDefault {
            return savedProfilesText
        }

        return HomeModelAdapter.localized(
            "home_pet_profile_meta_vaccines",
            fallback: "Vaccines"
        )
    }

    private var metaSecondary: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "home_pet_profile_meta_health",
                fallback: "Health details"
            )
        }

        if errorMessage != nil {
            return HomeModelAdapter.localized(
                "pet_profiles_title",
                fallback: "Pet Profiles"
            )
        }

        if defaultPet != nil {
            return savedProfilesText
        }

        if hasProfilesWithoutDefault {
            return HomeModelAdapter.localized(
                "home_pet_profile_set_default_meta",
                fallback: "Tap to set default"
            )
        }

        return HomeModelAdapter.localized(
            "home_pet_profile_meta_reminders",
            fallback: "Reminders"
        )
    }

    private var ctaTitle: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "home_pulse_loading_title",
                fallback: "Please wait"
            )
        }

        if errorMessage != nil {
            return HomeModelAdapter.localized(
                "Retry",
                fallback: "Retry"
            )
        }

        if defaultPet != nil {
            return HomeModelAdapter.localized(
                "home_pet_profile_open_cta",
                fallback: "Open pet profile"
            )
        }

        if hasProfilesWithoutDefault {
            return HomeModelAdapter.localized(
                "home_pet_profile_open_editor_cta",
                fallback: "Open pet editor"
            )
        }

        return HomeModelAdapter.localized(
            "pet_profiles_add_first",
            fallback: "Add your first pet"
        )
    }

    private var savedProfilesText: String {
        let nounKey = pets.count == 1 ? "pet_profile_single" : "pet_profiles_title"
        let nounFallback = pets.count == 1 ? "profile" : "Pet Profiles"
        return "\(pets.count) \(HomeModelAdapter.localized(nounKey, fallback: nounFallback))"
    }

    private func petDisplayName(_ pet: HomePetModel) -> String {
        let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return HomeModelAdapter.localized(
                "pet_name_placeholder",
                fallback: "Pet name"
            )
        }
        return name
    }

    private func petSummary(for pet: HomePetModel) -> String {
        let parts = [
            pet.breedOrCategory.trimmingCharacters(in: .whitespacesAndNewlines),
            pet.age.trimmingCharacters(in: .whitespacesAndNewlines),
        ].filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return HomeModelAdapter.localized(
                "pet_profiles_home_ready",
                fallback: "Care details ready on home"
            )
        }

        return parts.joined(separator: " · ")
    }

    private var avatarSymbol: String {
        if isLoading {
            return "hourglass.circle.fill"
        }
        if errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }
        if hasProfilesWithoutDefault {
            return "pawprint.circle.fill"
        }
        return "sparkles"
    }

    private var forwardSymbol: String {
        layoutDirection == .rightToLeft ? "arrow.left" : "arrow.right"
    }

    private var cardHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 330
        }

        let width = UIScreen.main.bounds.width
        if width >= 700 { return 258 }
        if width >= 430 { return 248 }
        if width < 375 { return 232 }
        return 240
    }

    private var avatarTextClearance: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 106 : 98
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: UnitPoint(x: 0, y: 0.18),
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        if isLoading {
            return colorScheme == .dark
                ? [
                    Color(red: 0.14, green: 0.10, blue: 0.08),
                    Color(red: 0.18, green: 0.13, blue: 0.10),
                ]
                : [
                    Color(red: 0.98, green: 0.92, blue: 0.82),
                    Color(red: 0.94, green: 0.83, blue: 0.71),
                ]
        }

        if defaultPet != nil {
            return colorScheme == .dark
                ? [
                    Color(red: 0.16, green: 0.10, blue: 0.06),
                    Color(red: 0.22, green: 0.12, blue: 0.06),
                ]
                : [
                    Color(red: 0.99, green: 0.88, blue: 0.76),
                    Color(red: 0.96, green: 0.65, blue: 0.43),
                ]
        }

        if hasProfilesWithoutDefault {
            return colorScheme == .dark
                ? [
                    Color(red: 0.15, green: 0.10, blue: 0.07),
                    Color(red: 0.20, green: 0.12, blue: 0.08),
                ]
                : [
                    Color(red: 0.99, green: 0.91, blue: 0.82),
                    Color(red: 0.96, green: 0.75, blue: 0.58),
                ]
        }

        return colorScheme == .dark
            ? [
                Color(red: 0.13, green: 0.10, blue: 0.07),
                Color(red: 0.18, green: 0.13, blue: 0.09),
            ]
            : [
                Color(red: 0.98, green: 0.93, blue: 0.86),
                Color(red: 0.95, green: 0.80, blue: 0.63),
            ]
    }

    private var orbColor: Color {
        if defaultPet != nil {
            return Color.ppPrimary.opacity(colorScheme == .dark ? 0.16 : 0.24)
        }

        if hasProfilesWithoutDefault {
            return Color(red: 0.95, green: 0.52, blue: 0.31)
                .opacity(colorScheme == .dark ? 0.12 : 0.22)
        }

        return Color(red: 0.93, green: 0.58, blue: 0.32)
            .opacity(colorScheme == .dark ? 0.10 : 0.18)
    }

    private var borderColor: Color {
        contrast == .increased
            ? Color.ppTextPrimary.opacity(0.45)
            : Color.ppBorder.opacity(0.08)
    }

    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0 : 0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.95, green: 0.90, blue: 0.86)
            : Color(red: 0.23, green: 0.13, blue: 0.10)
    }

    private var subtitleTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.85, green: 0.78, blue: 0.72).opacity(0.90)
            : Color(red: 0.33, green: 0.22, blue: 0.18).opacity(0.82)
    }

    private var tagTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.88, green: 0.82, blue: 0.76).opacity(0.94)
            : Color(red: 0.33, green: 0.22, blue: 0.18).opacity(0.94)
    }

    private var eyebrowTextColor: Color {
        colorScheme == .dark
            ? Color(red: 0.90, green: 0.82, blue: 0.74)
            : Color(red: 0.29, green: 0.18, blue: 0.10)
    }

    private var accessibilityLabel: String {
        [title, subtitle, metaPrimary, metaSecondary]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private var accessibilityHint: String {
        if isLoading {
            return HomeModelAdapter.localized(
                "pet_profiles_loading_home_subtitle",
                fallback: "Syncing your companion card and care details for the home feed."
            )
        }

        if defaultPet != nil || hasProfilesWithoutDefault {
            return HomeModelAdapter.localized(
                "home_pet_profile_open_hint",
                fallback: "Opens the pet profile editor"
            )
        }

        return HomeModelAdapter.localized(
            "home_pet_profile_create_hint",
            fallback: "Opens pet profiles so you can add your first pet"
        )
    }
}

private struct HomeGeneratedPetAvatar: View {
    let name: String
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(0.18),
                    Color.white.opacity(0.28),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initial)
                .font(HomeFont.bold(26))
                .foregroundStyle(accent.opacity(0.86))
                .minimumScaleFactor(0.6)
                .accessibilityHidden(true)
        }
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "P" }
        return String(first).uppercased()
    }
}

private struct HomeMyPetProfileCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(
                isEnabled
                    ? (configuration.isPressed ? 0.88 : 1)
                    : 0.62
            )
            .scaleEffect(
                reduceMotion || !isEnabled
                    ? 1
                    : (configuration.isPressed ? 0.986 : 1)
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(
                        response: configuration.isPressed ? 0.18 : 0.28,
                        dampingFraction: 0.88
                    ),
                value: configuration.isPressed
            )
    }
}

struct HomePriorityGrid: View {
    let actions: [HomePriorityAction]
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: PPSpace.sm)]
        }
        return [
            GridItem(.flexible(), spacing: PPSpace.sm),
            GridItem(.flexible(), spacing: PPSpace.sm),
            GridItem(.flexible(), spacing: PPSpace.sm),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Text(
                HomeModelAdapter.localized(
                    "home_pulse_priority_title",
                    fallback: "Your next step"
                )
            )
            .font(HomeFont.title2())
            .foregroundStyle(Color.ppTextPrimary)
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: PPSpace.sm) {
                ForEach(actions) { action in
                    Button {
                        onSelect(action)
                    } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            HStack(spacing: PPSpace.md) {
                                actionIcon(action)
                                actionCopy(action)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward")
                                    .foregroundStyle(Color.ppTextTertiary)
                                    .flipsForRightToLeftLayoutDirection(true)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: PPSpace.sm) {
                                actionIcon(action)
                                actionCopy(action)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(HomePriorityPressStyle())
                }
            }
        }
    }

    private func actionIcon(_ action: HomePriorityAction) -> some View {
        Image(systemName: action.systemImage)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(Color(uiColor: action.accent))
            .frame(width: 42, height: 42)
            .background(
                Color(uiColor: action.accent).opacity(0.12),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private func actionCopy(_ action: HomePriorityAction) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(action.title)
                .font(HomeFont.bold(15))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text(action.subtitle)
                .font(HomeFont.caption1())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomePriorityPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(PPSpace.md)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(
                configuration.isPressed
                    ? Color.ppSecondarySurface
                    : Color.ppSurface,
                in: RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .stroke(Color.ppBorder, lineWidth: 0.6)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct HomeCategoryRail: View {
    let categories: [HomeCategoryModel]
    let selectedID: Int?
    let onSelect: (HomeCategoryModel?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_pulse_categories_title",
                    fallback: "Explore by pet"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_categories_subtitle",
                    fallback: "The selected species shapes relevant results"
                ),
                actionTitle: nil,
                action: nil
            )
            .padding(.horizontal, PPSpace.screenMargin)

            HomeMainKindsCollectionRepresentable(
                categories: categories,
                selectedID: selectedID,
                itemSize: itemSize,
                onSelect: onSelect
            )
            .frame(height: itemSize.height + PPSpace.sm)
        }
    }

    private var itemSize: CGSize {
        let width = UIScreen.main.bounds.width
        let accessibility = dynamicTypeSize.isAccessibilitySize
        if width >= 700 {
            return CGSize(
                width: accessibility ? 152 : 132,
                height: accessibility ? 174 : 146
            )
        }
        if width >= 430 {
            return CGSize(
                width: accessibility ? 126 : 108,
                height: accessibility ? 154 : 132
            )
        }
        if width < 375 {
            return CGSize(
                width: accessibility ? 120 : 104,
                height: accessibility ? 150 : 128
            )
        }
        return CGSize(
            width: accessibility ? 124 : 108,
            height: accessibility ? 152 : 132
        )
    }
}

private struct HomeMainKindsCollectionRepresentable: UIViewRepresentable {
    let categories: [HomeCategoryModel]
    let selectedID: Int?
    let itemSize: CGSize
    let onSelect: (HomeCategoryModel?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = PPSpace.md
        layout.minimumInteritemSpacing = PPSpace.md
        layout.sectionInset = UIEdgeInsets(
            top: PPSpace.xs,
            left: PPSpace.screenMargin,
            bottom: PPSpace.xs,
            right: PPSpace.screenMargin
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.decelerationRate = .fast
        collectionView.semanticContentAttribute =
            Language.semanticAttributeForCurrentLanguage()
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(
            PPMainKindsCell.self,
            forCellWithReuseIdentifier: PPMainKindsCell.reuseIdentifier
        )
        return collectionView
    }

    func updateUIView(
        _ collectionView: UICollectionView,
        context: Context
    ) {
        context.coordinator.update(
            categories: categories,
            selectedID: selectedID,
            itemSize: itemSize,
            onSelect: onSelect,
            collectionView: collectionView
        )
    }

    final class Coordinator: NSObject, UICollectionViewDataSource,
        UICollectionViewDelegate
    {
        private static let loopCycleCount = 101

        private var categories: [HomeCategoryModel] = []
        private var selectedID: Int?
        private var onSelect: ((HomeCategoryModel?) -> Void)?
        private var itemSize: CGSize = .zero
        private var contentSignature = ""
        private var selectionSignature = Int.min
        private var positioningGeneration = 0
        private var hasEstablishedLoopPosition = false
        private weak var collectionView: UICollectionView?

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(voiceOverStatusDidChange),
                name: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        private var logicalItemCount: Int {
            categories.count + 1
        }

        private var usesInfiniteLoop: Bool {
            logicalItemCount > 1 && !UIAccessibility.isVoiceOverRunning
        }

        private var presentedItemCount: Int {
            guard usesInfiniteLoop else { return logicalItemCount }
            return logicalItemCount * Self.loopCycleCount
        }

        func update(
            categories: [HomeCategoryModel],
            selectedID: Int?,
            itemSize: CGSize,
            onSelect: @escaping (HomeCategoryModel?) -> Void,
            collectionView: UICollectionView
        ) {
            self.categories = categories
            self.selectedID = selectedID
            self.itemSize = itemSize
            self.onSelect = onSelect
            self.collectionView = collectionView

            if let layout =
                collectionView.collectionViewLayout
                    as? UICollectionViewFlowLayout,
               layout.itemSize != itemSize {
                layout.itemSize = itemSize
                layout.invalidateLayout()
            }
            updateEdgeInsets(in: collectionView)

            let nextContentSignature = [
                categories.map {
                    [
                        $0.id,
                        String(HomeModelAdapter.mainKindID($0.raw)),
                        $0.title,
                        $0.imageURL ?? "",
                    ].joined(separator: "|")
                }.joined(separator: ";"),
                "\(itemSize.width)x\(itemSize.height)",
                UIAccessibility.isVoiceOverRunning ? "voice-over" : "visual",
            ].joined(separator: "#")
            let nextSelectionSignature = selectedID ?? -1
            let contentChanged = nextContentSignature != contentSignature
            let selectionChanged =
                nextSelectionSignature != selectionSignature

            guard contentChanged || selectionChanged else { return }
            if contentChanged {
                hasEstablishedLoopPosition = false
            }
            contentSignature = nextContentSignature
            selectionSignature = nextSelectionSignature
            collectionView.reloadData()
            positionSelectedItem(in: collectionView)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            numberOfItemsInSection section: Int
        ) -> Int {
            presentedItemCount
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PPMainKindsCell.reuseIdentifier,
                for: indexPath
            ) as? PPMainKindsCell else {
                return UICollectionViewCell()
            }

            let logicalIndex = logicalIndex(for: indexPath.item)
            let isAll = logicalIndex == 0
            let category = isAll ? nil : categories[logicalIndex - 1]
            let categoryID = category.map {
                HomeModelAdapter.mainKindID($0.raw)
            }
            let selected = isAll
                ? selectedID == nil
                : categoryID == selectedID

            cell.configure(
                withMainKind: category?.raw,
                isAll: isAll,
                selected: selected,
                restoredSelectionAppearance: false
            )
            applySelectionScale(
                to: cell,
                selected: selected,
                animated: cell.window != nil
            )
            cell.onSelect = { [weak self, weak collectionView] _, selectedAll in
                guard let self, let collectionView else { return }
                self.centerItem(
                    at: indexPath,
                    in: collectionView,
                    animated: !UIAccessibility.isReduceMotionEnabled
                )
                self.onSelect?(selectedAll ? nil : category)
            }
            return cell
        }

        private func applySelectionScale(
            to cell: UICollectionViewCell,
            selected: Bool,
            animated: Bool
        ) {
            let targetTransform = selected
                ? CGAffineTransform(scaleX: 1.035, y: 1.035)
                : .identity
            cell.layer.zPosition = selected ? 1 : 0

            guard cell.transform != targetTransform else { return }
            guard animated, !UIAccessibility.isReduceMotionEnabled else {
                cell.transform = targetTransform
                return
            }

            UIView.animate(
                withDuration: 0.26,
                delay: 0,
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.12,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: {
                    cell.transform = targetTransform
                }
            )
        }

        private func positionSelectedItem(
            in collectionView: UICollectionView
        ) {
            positioningGeneration += 1
            let generation = positioningGeneration
            let selectedLogicalIndex: Int
            if let selectedID,
               let categoryIndex = categories.firstIndex(where: {
                   HomeModelAdapter.mainKindID($0.raw) == selectedID
               }) {
                selectedLogicalIndex = categoryIndex + 1
            } else {
                selectedLogicalIndex = 0
            }

            DispatchQueue.main.async { [weak self, weak collectionView] in
                guard let self,
                      let collectionView,
                      generation == self.positioningGeneration
                else {
                    return
                }
                collectionView.layoutIfNeeded()
                let targetIndex = self.virtualIndex(
                    for: selectedLogicalIndex,
                    nearestToCurrentPositionIn: collectionView
                )
                guard collectionView.numberOfItems(inSection: 0)
                    > targetIndex else {
                    return
                }
                self.centerItem(
                    at: IndexPath(item: targetIndex, section: 0),
                    in: collectionView,
                    animated: false
                )
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        func scrollViewDidEndDragging(
            _ scrollView: UIScrollView,
            willDecelerate decelerate: Bool
        ) {
            guard !decelerate,
                  let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        func scrollViewDidEndScrollingAnimation(
            _ scrollView: UIScrollView
        ) {
            guard let collectionView = scrollView as? UICollectionView else {
                return
            }
            recenterLoopIfNeeded(in: collectionView)
        }

        private func logicalIndex(for virtualIndex: Int) -> Int {
            guard logicalItemCount > 0 else { return 0 }
            return virtualIndex % logicalItemCount
        }

        private func virtualIndex(
            for logicalIndex: Int,
            nearestToCurrentPositionIn collectionView: UICollectionView
        ) -> Int {
            guard usesInfiniteLoop else { return logicalIndex }

            let middleCycleStart =
                (Self.loopCycleCount / 2) * logicalItemCount
            guard hasEstablishedLoopPosition,
                  let centeredIndex = centeredVirtualIndex(
                    in: collectionView
                  ) else {
                return middleCycleStart + logicalIndex
            }

            let centeredLogicalIndex = self.logicalIndex(
                for: centeredIndex
            )
            let forwardDistance =
                (logicalIndex - centeredLogicalIndex + logicalItemCount)
                % logicalItemCount
            let backwardDistance = forwardDistance - logicalItemCount
            let shortestDistance =
                abs(forwardDistance) <= abs(backwardDistance)
                ? forwardDistance
                : backwardDistance
            let nearestIndex = centeredIndex + shortestDistance

            guard nearestIndex >= 0,
                  nearestIndex < presentedItemCount else {
                return middleCycleStart + logicalIndex
            }
            return nearestIndex
        }

        private func centeredVirtualIndex(
            in collectionView: UICollectionView
        ) -> Int? {
            let visibleCenter = CGPoint(
                x: collectionView.contentOffset.x
                    + collectionView.bounds.width / 2,
                y: collectionView.contentOffset.y
                    + collectionView.bounds.height / 2
            )
            if let exact = collectionView.indexPathForItem(
                at: visibleCenter
            ) {
                return exact.item
            }

            return collectionView.indexPathsForVisibleItems.min {
                let lhsCenter = collectionView.layoutAttributesForItem(
                    at: $0
                )?.center.x ?? .greatestFiniteMagnitude
                let rhsCenter = collectionView.layoutAttributesForItem(
                    at: $1
                )?.center.x ?? .greatestFiniteMagnitude
                return abs(lhsCenter - visibleCenter.x)
                    < abs(rhsCenter - visibleCenter.x)
            }?.item
        }

        private func centerItem(
            at indexPath: IndexPath,
            in collectionView: UICollectionView,
            animated: Bool
        ) {
            guard indexPath.item >= 0,
                  indexPath.item
                    < collectionView.numberOfItems(inSection: 0) else {
                return
            }
            hasEstablishedLoopPosition = true
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredHorizontally,
                animated: animated
            )
        }

        private func recenterLoopIfNeeded(
            in collectionView: UICollectionView
        ) {
            guard usesInfiniteLoop,
                  let centeredIndex = centeredVirtualIndex(
                    in: collectionView
                  ) else {
                return
            }

            let edgeBuffer = logicalItemCount * 10
            guard centeredIndex < edgeBuffer
                    || centeredIndex
                        >= presentedItemCount - edgeBuffer else {
                return
            }

            let middleIndex =
                (Self.loopCycleCount / 2) * logicalItemCount
                + logicalIndex(for: centeredIndex)
            let sourceIndexPath = IndexPath(
                item: centeredIndex,
                section: 0
            )
            let targetIndexPath = IndexPath(
                item: middleIndex,
                section: 0
            )
            collectionView.layoutIfNeeded()
            guard let sourceAttributes =
                    collectionView.layoutAttributesForItem(
                        at: sourceIndexPath
                    ),
                  let targetAttributes =
                    collectionView.layoutAttributesForItem(
                        at: targetIndexPath
                    ) else {
                centerItem(
                    at: targetIndexPath,
                    in: collectionView,
                    animated: false
                )
                return
            }

            var offset = collectionView.contentOffset
            offset.x +=
                targetAttributes.center.x - sourceAttributes.center.x
            collectionView.setContentOffset(offset, animated: false)
            hasEstablishedLoopPosition = true
        }

        private func updateEdgeInsets(
            in collectionView: UICollectionView
        ) {
            guard let layout =
                    collectionView.collectionViewLayout
                        as? UICollectionViewFlowLayout else {
                return
            }
            let finiteCenterInset = max(
                PPSpace.screenMargin,
                (collectionView.bounds.width - itemSize.width) / 2
            )
            let horizontalInset = usesInfiniteLoop
                ? PPSpace.screenMargin
                : finiteCenterInset
            let nextInsets = UIEdgeInsets(
                top: PPSpace.xs,
                left: horizontalInset,
                bottom: PPSpace.xs,
                right: horizontalInset
            )
            guard layout.sectionInset != nextInsets else { return }
            layout.sectionInset = nextInsets
            layout.invalidateLayout()
        }

        @objc
        private func voiceOverStatusDidChange() {
            guard let collectionView else { return }
            hasEstablishedLoopPosition = false
            contentSignature = ""
            updateEdgeInsets(in: collectionView)
            collectionView.reloadData()
            positionSelectedItem(in: collectionView)
        }
    }
}

struct HomeOrderCard: View {
    let order: HomeOrderModel
    let onTap: () -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: HomeModelAdapter.localized(
                    "home_pulse_current_order_title",
                    fallback: "Current order"
                ),
                subtitle: order.reference,
                actionTitle: HomeModelAdapter.localized(
                    "home_pulse_orders",
                    fallback: "Orders"
                ),
                action: onSeeAll
            )

            Button(action: onTap) {
                HStack(spacing: PPSpace.md) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: PPCorner.medium,
                            style: .continuous
                        )
                        .fill(Color.ppSoftRose)
                        Image(systemName: order.symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ppPrimary)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: PPSpace.xs) {
                        Text(order.statusTitle)
                            .font(HomeFont.headline())
                            .foregroundStyle(Color.ppTextPrimary)
                        Text(order.statusHint)
                            .font(HomeFont.footnote())
                            .foregroundStyle(Color.ppTextSecondary)
                            .lineLimit(2)
                        ProgressView(value: order.progress)
                            .tint(Color.ppPrimary)
                            .accessibilityLabel(order.statusTitle)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: PPSpace.xs) {
                        if !order.amount.isEmpty {
                            Text(order.amount)
                                .font(HomeFont.bold(15))
                                .foregroundStyle(Color.ppTextPrimary)
                        }
                        Text(
                            String(
                                format: HomeModelAdapter.localized(
                                    "home_pulse_order_items",
                                    fallback: "%d items"
                                ),
                                order.itemCount
                            )
                        )
                        .font(HomeFont.caption1())
                        .foregroundStyle(Color.ppTextSecondary)
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Color.ppPrimary)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                }
                .padding(PPSpace.base)
                .background(Color.ppSurface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PPCorner.card,
                        style: .continuous
                    )
                    .stroke(Color.ppBorder, lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                HomeModelAdapter.localized(
                    "home_pulse_order_details_a11y",
                    fallback: "Opens order details"
                )
            )
        }
    }
}

struct HomeFeedSection: View {
    let section: HomeSectionModel
    let store: HomeStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let thirdCardPeekFraction: CGFloat = 0.12

    private var cardRailHeight: CGFloat {
        328 + (PPSpace.xs * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HomeSectionHeader(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: section.seeAllTitle,
                action: section.seeAllTitle == nil
                    ? nil
                    : { store.seeAll(section.id) }
            )
            .padding(.horizontal, PPSpace.screenMargin)

            switch section.state {
            case .loading:
                GeometryReader { geometry in
                    HomeCardSkeletonRail(
                        cardWidth: cardWidth(
                            in: geometry.size.width,
                            itemCount: 4
                        )
                    )
                }
                .frame(height: cardRailHeight)
            case let .content(cards):
                GeometryReader { geometry in
                    let resolvedCardWidth = cardWidth(
                        in: geometry.size.width,
                        itemCount: cards.count
                    )
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: PPSpace.md) {
                            ForEach(cards) { card in
                                HomeUniversalCard(
                                    card: card,
                                    delegate: store.router.universalCardDelegate,
                                    onTap: { store.tapCard(card) },
                                    onQuantityChange: {
                                        store.setQuantity($0, for: card)
                                    }
                                )
                                .frame(width: resolvedCardWidth)
                            }
                        }
                        .padding(.leading, PPSpace.screenMargin)
                        .padding(.vertical, PPSpace.xs)
                    }
                    .contentMarginsCompat()
                }
                .frame(height: cardRailHeight)
            case let .empty(title, message, actionTitle):
                HomeInlineState(
                    symbol: "tray",
                    title: title,
                    message: message,
                    actionTitle: actionTitle,
                    action: actionTitle == nil
                        ? nil
                        : { store.seeAll(section.id) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            case let .failed(title, message, retryTitle):
                HomeInlineState(
                    symbol: "arrow.clockwise.circle",
                    title: title,
                    message: message,
                    actionTitle: retryTitle,
                    action: { store.retry(section: section.id) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func cardWidth(
        in viewportWidth: CGFloat,
        itemCount: Int
    ) -> CGFloat {
        // Reserve the semantic leading margin inside the scroll content so
        // every universal-card section starts aligned with its section title.
        // The opposite edge intentionally stays at zero inset.
        let availableWidth = max(
            0,
            viewportWidth - PPSpace.screenMargin
        )
        guard itemCount > 1 else { return availableWidth }

        let spacing = PPSpace.md
        let usesReadableSingleCard =
            dynamicTypeSize.isAccessibilitySize || viewportWidth < 350
        if usesReadableSingleCard {
            return max(
                0,
                (availableWidth - spacing)
                    / (1 + thirdCardPeekFraction)
            )
        }

        guard itemCount > 2 else {
            return max(0, (availableWidth - spacing) / 2)
        }

        // Leading margin + two complete cards + two gaps + 12% of the third.
        return max(
            0,
            (availableWidth - (spacing * 2))
                / (2 + thirdCardPeekFraction)
        )
    }
}

struct HomeSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.md) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(HomeFont.title2())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(HomeFont.subheadline())
                        .foregroundStyle(Color.ppTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
            }
        }
    }
}

struct HomeStatusBanner: View {
    let state: HomeViewState
    let retry: () -> Void

    var body: some View {
        if state.connectivity == .offline {
            banner(
                symbol: "wifi.slash",
                title: state.hasStaleContent
                    ? HomeModelAdapter.localized(
                        "home_pulse_offline_stale",
                        fallback: "Offline — showing saved content"
                    )
                    : HomeModelAdapter.localized(
                        "home_pulse_offline",
                        fallback: "You are offline"
                    ),
                tint: .ppWarning,
                actionTitle: HomeModelAdapter.localized(
                    "Retry",
                    fallback: "Retry"
                ),
                action: retry
            )
        } else if case .partial = state.phase {
            banner(
                symbol: "exclamationmark.circle",
                title: HomeModelAdapter.localized(
                    "home_pulse_partial",
                    fallback: "Some sections could not update"
                ),
                tint: .ppWarning,
                actionTitle: HomeModelAdapter.localized(
                    "Retry",
                    fallback: "Retry"
                ),
                action: retry
            )
        } else if case .refreshing = state.phase {
            banner(
                symbol: "arrow.clockwise",
                title: HomeModelAdapter.localized(
                    "home_pulse_refreshing",
                    fallback: "Refreshing Home"
                ),
                tint: .ppInfo,
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func banner(
        symbol: String,
        title: String,
        tint: Color,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(title)
                .font(HomeFont.footnote())
                .foregroundStyle(Color.ppTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(13))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, PPSpace.md)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.28), lineWidth: 0.7))
    }
}

struct HomeInlineState: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 50, height: 50)
                .background(Color.ppSoftRose, in: Circle())
            Text(title)
                .font(HomeFont.headline())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HomeFont.bold(14))
                    .foregroundStyle(Color.white)
                    .frame(minHeight: 46)
                    .padding(.horizontal, PPSpace.base)
                    .background(Color.ppPrimary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PPSpace.lg)
        .background(Color.ppSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppBorder, lineWidth: 0.7)
        }
    }
}

private struct HomeCardSkeletonRail: View {
    private static let skeletonIDs = [
        "home-card-skeleton-1",
        "home-card-skeleton-2",
        "home-card-skeleton-3",
        "home-card-skeleton-4",
    ]

    let cardWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: PPSpace.md) {
                ForEach(Self.skeletonIDs, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        RoundedRectangle(cornerRadius: PPCorner.medium)
                            .fill(Color.ppSeparator.opacity(0.7))
                            .frame(height: 166)
                        Capsule().fill(Color.ppSeparator).frame(height: 16)
                        Capsule()
                            .fill(Color.ppSeparator)
                            .frame(width: 100, height: 13)
                        Spacer()
                        Capsule().fill(Color.ppSoftRose).frame(height: 46)
                    }
                    .padding(PPSpace.sm)
                    .frame(width: cardWidth, height: 328)
                    .background(Color.ppSurface)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PPCorner.card,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)
                }
            }
            .padding(.leading, PPSpace.screenMargin)
            .padding(.vertical, PPSpace.xs)
        }
        .contentMarginsCompat()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_section_loading",
                fallback: "Loading section"
            )
        )
    }
}

struct HomeRemoteImage: UIViewRepresentable {
    let urlString: String?
    let placeholder: UIImage?
    let contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.ppSecondarySurface
        imageView.isAccessibilityElement = false
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode
        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: urlString,
            placeholder: placeholder,
            transitionStyle: .fade,
            completion: nil
        )
    }

    static func dismantleUIView(
        _ imageView: UIImageView,
        coordinator: Void
    ) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }
}

private extension View {
    @ViewBuilder
    func contentMarginsCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.contentMargins(.horizontal, 0, for: .scrollContent)
        } else {
            self
        }
    }
}
