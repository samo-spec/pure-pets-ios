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

@available(iOS 15.0, *)
struct HomeCommandBar: View {
    let state: HomeViewState
    let searchAction: () -> Void
    let cartAction: () -> Void
    let locationAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var searchControlHeight: CGFloat = 54

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            if state.config.titleViewMode == "location" {
                locationButton
                compactSearchButton
            } else {
                searchButton
            }
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

    private var locationButton: some View {
        Button(action: locationAction) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.homeBrand)
                    .frame(width: 38, height: 38)
                    .background(Color.homeAmbientField, in: RoundedRectangle(
                        cornerRadius: PPCorner.small,
                        style: .continuous
                    ))

                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeModelAdapter.localized(
                        "home_pulse_location_context",
                        fallback: "Your area"
                    ))
                    .font(HomeFont.caption1())
                    .foregroundStyle(Color.homeTextSecondary)
                    Text(locationTitle)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.homeTextPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.homeTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.sm)
            .frame(maxWidth: .infinity, minHeight: resolvedSearchControlHeight)
            .background(Color.homeRaisedSurface, in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            ))
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                    .stroke(Color.homeSeparator, lineWidth: contrast == .increased ? 1.5 : 0.8)
            }
        }
        .buttonStyle(HomeSearchButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(locationTitle)
    }

    private var compactSearchButton: some View {
        Button(action: searchAction) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.homeBrand)
                .frame(width: 48, height: 48)
                .background(Color.homeRaisedSurface, in: Circle())
                .overlay(Circle().stroke(Color.homeSeparator, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeModelAdapter.localized(
            "home_pulse_search_a11y",
            fallback: "Search Pure Pets"
        ))
    }

    private var locationTitle: String {
        let area = state.location.areaName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !area.isEmpty {
            return area
        }
        switch state.location.presentation {
        case .loading:
            return HomeModelAdapter.localized("Loading...", fallback: "Loading")
        case .denied, .restricted:
            return HomeModelAdapter.localized(
                "Location permission denied",
                fallback: "Location unavailable"
            )
        case .notDetermined, .ready, .failed:
            return HomeModelAdapter.localized(
                "Select your location",
                fallback: "Choose an area"
            )
        }
    }

    private var searchButton: some View {
        Button(action: searchAction) {
            HStack(spacing: PPSpace.sm) {
                searchGlyph

                HomeAnimatedSearchSuggestionView(isRTL: state.isRightToLeft)
                    .layoutPriority(1)
            }
            .padding(.horizontal, PPSpace.sm)
            .frame(
                maxWidth: .infinity,
                minHeight: resolvedSearchControlHeight,
                alignment: .leading
            )
            .background(searchSurface)
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .stroke(
                    contrast == .increased
                        ? AnyShapeStyle(Color.ppTextPrimary.opacity(0.66))
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.ppPrimary.opacity(0.20),
                                    Color.ppBorder,
                                    Color.white.opacity(
                                        colorScheme == .dark ? 0.05 : 0.70
                                    ),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
            .shadow(
                color: contrast == .increased
                    ? .clear
                    : Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07),
                radius: colorScheme == .dark ? 10 : 14,
                y: colorScheme == .dark ? 4 : 7
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
            )
        }
        .buttonStyle(HomeSearchButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_search_a11y",
                fallback: "Search Pure Pets"
            )
        )
    }

    private var resolvedSearchControlHeight: CGFloat {
        let maximum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 68 : 58
        return min(max(searchControlHeight, 54), maximum)
    }

    private var searchGlyph: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
            .fill(
                Color.ppSoftRose.opacity(colorScheme == .dark ? 0.34 : 0.72)
            )

            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Circle()
                .fill(Color.ppPrimary)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Color.ppElevatedSurface, lineWidth: 2))
                .offset(x: 2, y: 2)
        }
        .frame(width: 38, height: 38)
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
            .stroke(Color.ppPrimary.opacity(0.10), lineWidth: 0.7)
        }
        .accessibilityHidden(true)
    }

    private var searchSurface: some View {
        RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
        .fill(
            Color.ppElevatedSurface.opacity(
                contrast == .increased
                    ? 1
                    : (colorScheme == .dark ? 0.96 : 0.92)
            )
        )
    }

    private struct HomeSearchButtonStyle: ButtonStyle {
        let reduceMotion: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(
                    configuration.isPressed && !reduceMotion ? 0.986 : 1
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
        }
    }

@available(iOS 15.0, *)
private struct SearchSuggestion: Identifiable {
    let id: String
    let text: String
}

@available(iOS 15.0, *)
struct HomeAnimatedSearchSuggestionView: View {
    let isRTL: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentSuggestionID =
        "home_search_suggestion_cat_food"

    private var suggestions: [SearchSuggestion] {
        let keys = [
            "home_search_suggestion_cat_food",
            "home_search_suggestion_grooming",
            "home_search_suggestion_dog_accessories",
            "home_search_suggestion_veterinary",
            "home_search_suggestion_medicine",
            "home_search_suggestion_pet_listings",
            "home_search_suggestion_cat_hygiene",
        ]
        let localized = keys.compactMap { key -> SearchSuggestion? in
            let text = HomeModelAdapter.localized(key, fallback: "")
            return text.isEmpty ? nil : SearchSuggestion(id: key, text: text)
        }
        if !localized.isEmpty {
            return localized
        }
        return [
            SearchSuggestion(
                id: "home_pulse_search_prompt",
                text: HomeModelAdapter.localized(
                    "home_pulse_search_prompt",
                    fallback: ""
                )
            ),
        ]
    }

    private var visibleSuggestionID: String {
        suggestions.contains(where: { $0.id == currentSuggestionID })
            ? currentSuggestionID
            : (suggestions.first?.id ?? "")
    }

    private var rotationTaskID: String {
        "\(scenePhase == .active)-\(reduceMotion)-\(isRTL)"
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(suggestions) { item in
                if item.id == visibleSuggestionID {
                    Text(item.text)
                        .font(HomeFont.callout())
                        .foregroundStyle(Color.ppTextPrimary.opacity(0.76))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.leading)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                )
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 30 : 24)
        .clipped()
        .accessibilityHidden(true)
        .task(id: rotationTaskID) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled, !suggestions.isEmpty else { return }

                let currentIndex = suggestions.firstIndex(where: { $0.id == visibleSuggestionID }) ?? 0
                let nextIndex = (currentIndex + 1) % suggestions.count
                let next = suggestions[nextIndex]

                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.20)
                        : .spring(response: 0.44, dampingFraction: 0.82)
                ) {
                    currentSuggestionID = next.id
                }
            }
        }
    }
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
        LinearGradient(
            stops: [
                .init(color: Color.homeCanvas, location: 0),
                .init(
                    color: Color.homeCanvas.opacity(
                        contrast == .increased ? 0.98 : 0.90
                    ),
                    location: 0.72
                ),
                .init(color: Color.homeCanvas.opacity(0), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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

@available(iOS 15.0, *)
struct HomePetSwitcher: View {
    let pets: [HomePetModel]
    let selectedID: String?
    let onSelect: (HomePetModel) -> Void
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPSectionHeaderSwiftUIRepresentable(
                title: HomeModelAdapter.localized(
                    "home_pulse_pet_context_title",
                    fallback: "Your pet context"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_pet_context_subtitle",
                    fallback: "Home priorities follow the selected pet"
                ),
                actionTitle: HomeModelAdapter.localized(
                    "Edit",
                    fallback: "Edit"
                ),
                action: onEdit,
                sectionRawValue: 8
            )
            .padding(.horizontal, PPSpace.screenMargin * 0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: PPSpace.sm) {
                    ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                        HomePetIdentityPill(
                            pet: pet,
                            selected: pet.id == selectedID,
                            onSelect: {
                                onSelect(pet)
                            }
                        )
                        .modifier(HomePetPillCascade(ordinal: index))
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            }
            .contentMarginsCompat()
        }
    }
}

private struct HomePetIdentityPill: View {
    let pet: HomePetModel
    let selected: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool

    private let shape = RoundedRectangle(
        cornerRadius: 28,
        style: .continuous
    )

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: PPSpace.sm) {
                portrait

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(HomeFont.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .minimumScaleFactor(0.82)

                    if let petContext {
                        Text(petContext)
                            .font(HomeFont.footnote())
                            .foregroundStyle(Color.ppTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(
                                dynamicTypeSize.isAccessibilitySize ? 3 : 1
                            )
                            .minimumScaleFactor(0.82)
                    }

                    if selected {
                        selectedBadge
                            .transition(selectionBadgeTransition)
                    }
                }
                .layoutPriority(1)
            }
            .padding(.leading, PPSpace.sm)
            .padding(.trailing, PPSpace.md)
            .padding(.vertical, PPSpace.sm)
            .frame(
                minWidth: minimumWidth,
                maxWidth: maximumWidth,
                minHeight: minimumHeight,
                alignment: .leading
            )
            .background {
                shape.fill(surfaceBackground)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .overlay(alignment: .topTrailing) {
                if pet.isDefault && !selected {
                    defaultDot
                        .padding(8)
                }
            }
            .overlay {
                if isFocused {
                    shape.strokeBorder(
                        Color.ppPrimary,
                        lineWidth: contrast == .increased ? 3 : 2.4
                    )
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(HomePetIdentityPressStyle())
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_pet_context_subtitle",
                fallback: "Home priorities follow the selected pet"
            )
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(selectionAnimation, value: selected)
    }

    private var portrait: some View {
        ZStack {
            Circle()
                .fill(
                    selected
                        ? Color.ppPrimary.opacity(
                            colorScheme == .dark ? 0.18 : 0.13
                        )
                        : Color.ppSecondarySurface
                )

            portraitContent
                .frame(width: portraitImageDiameter, height: portraitImageDiameter)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(
                        Color.ppSurface.opacity(
                            contrast == .increased ? 1 : 0.92
                        ),
                        lineWidth: 2
                    )
                }
        }
        .frame(width: portraitDiameter, height: portraitDiameter)
        .overlay {
            Circle().strokeBorder(
                selected
                    ? Color.ppPrimary.opacity(
                        contrast == .increased ? 1 : 0.90
                    )
                    : Color.ppBorder.opacity(
                        contrast == .increased ? 0.70 : 0.42
                    ),
                lineWidth: selected
                    ? (contrast == .increased ? 2.4 : 1.5)
                    : (contrast == .increased ? 1.4 : 0.8)
            )
        }
        .overlay(alignment: .bottomTrailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 21, height: 21)
                    .background(Color.ppPrimary, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.ppSurface, lineWidth: 2)
                    }
                    .transition(selectionBadgeTransition)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var portraitContent: some View {
        if let imageURL = normalizedImageURL {
            HomeRemoteImage(
                urlString: imageURL,
                placeholder: UIImage(named: "petcare_placeholder"),
                contentMode: .scaleAspectFill,
                cacheKey: pet.id,
                displaySize: CGSize(
                    width: portraitImageDiameter,
                    height: portraitImageDiameter
                )
            )
        } else {
            HomeGeneratedPetAvatar(
                name: displayName,
                accent: selected ? Color.ppPrimary : Color.ppTextTertiary
            )
        }
    }

    private var selectedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)

            Text(
                HomeModelAdapter.localized(
                    "modern_segmented_selected",
                    fallback: "Selected"
                )
            )
            .font(HomeFont.caption2())
            .lineLimit(1)
        }
        .foregroundStyle(Color.ppPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.ppPrimary.opacity(0.10), in: Capsule())
    }

    private var defaultDot: some View {
        Circle()
            .fill(Color.ppPrimary.opacity(0.72))
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    private var displayName: String {
        let name = pet.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !name.isEmpty else {
            return HomeModelAdapter.localized(
                "pet_name_placeholder",
                fallback: "Pet name"
            )
        }
        return name
    }

    private var petContext: String? {
        let context = [pet.breedOrCategory, pet.age]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        return context.isEmpty ? nil : context
    }

    private var normalizedImageURL: String? {
        let imageURL = pet.imageURL?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let imageURL, !imageURL.isEmpty else { return nil }
        return imageURL
    }

    private var accessibilityLabel: String {
        let label = [displayName, petContext]
            .compactMap { $0 }
            .joined(separator: ", ")
        guard selected else { return label }
        return String(
            format: HomeModelAdapter.localized(
                "home_pulse_pet_selected_a11y",
                fallback: "%@ selected"
            ),
            label
        )
    }

    private var surfaceBackground: some ShapeStyle {
        if selected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.ppSoftRose.opacity(
                            colorScheme == .dark ? 0.42 : 0.92
                        ),
                        Color.ppSurface.opacity(
                            colorScheme == .dark ? 0.96 : 0.98
                        ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.ppSurface)
    }

    private var borderColor: Color {
        if selected {
            return Color.ppPrimary.opacity(
                contrast == .increased ? 1 : 0.48
            )
        }
        return contrast == .increased
            ? Color.ppTextPrimary.opacity(0.68)
            : Color.ppBorder.opacity(0.62)
    }

    private var borderWidth: CGFloat {
        if selected {
            return contrast == .increased ? 2 : 0.9
        }
        return contrast == .increased ? 1.4 : 0.7
    }

    private var portraitDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 66 : 58
    }

    private var portraitImageDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 58 : 50
    }

    private var minimumWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 232 : 188
    }

    private var maximumWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 340 : 286
    }

    private var minimumHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 108 : 86
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(
                response: 0.36,
                dampingFraction: 0.88,
                blendDuration: 0.08
            )
    }

    private var selectionBadgeTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .scale(scale: 0.88).combined(with: .opacity)
    }
}

private struct HomePetIdentityPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(
                isEnabled
                    ? (configuration.isPressed ? 0.86 : 1)
                    : 0.52
            )
            .scaleEffect(
                reduceMotion || !isEnabled
                    ? 1
                    : (configuration.isPressed ? 0.982 : 1)
            )
            .shadow(
                color: Color.black.opacity(
                    isEnabled && !configuration.isPressed ? 0.055 : 0
                ),
                radius: isEnabled && !configuration.isPressed ? 18 : 0,
                y: isEnabled && !configuration.isPressed ? 10 : 0
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .easeOut(
                        duration: configuration.isPressed ? 0.08 : 0.16
                    ),
                value: configuration.isPressed
            )
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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

            decorativeLayer

            cardShape.strokeBorder(
                borderColor,
                lineWidth: contrast == .increased ? 1.4 : 0.8
            )

            contentLayer
                .padding(PPSpace.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardMinHeight)
        .contentShape(cardShape)
        .shadow(
            color: PPShadow.card.color,
            radius: colorScheme == .dark ? 0 : PPShadow.card.radius,
            x: PPShadow.card.x,
            y: colorScheme == .dark ? 0 : PPShadow.card.y
        )
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
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [accentGlow, Color.clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 170
                    )
                )
                .clipShape(cardShape)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 86, weight: .black))
                .foregroundStyle(
                    Color.ppPrimary.opacity(
                        colorScheme == .dark ? 0.05 : 0.06
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottomTrailing)
                .padding(.trailing, PPSpace.sm)
                .padding(.bottom, PPSpace.sm)
        }
        .accessibilityHidden(true)
    }

    private var contentLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    avatar
                    copyStack
                }
            } else {
                HStack(alignment: .top, spacing: PPSpace.lg) {
                    avatar
                    copyStack
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(
                minLength: dynamicTypeSize.isAccessibilitySize
                    ? PPSpace.md : PPSpace.base
            )

            metaRow

            ctaView
                .padding(.top, PPSpace.md)
        }
    }

    private var copyStack: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            eyebrowChip

            Text(title)
                .font(HomeFont.bold(24))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.84)
                .allowsTightening(true)
                .frame(minHeight: 30, alignment: .leading)
                .padding(.top, PPSpace.xxs)

            Text(subtitle)
                .font(HomeFont.medium(13))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eyebrowChip: some View {
        HStack(spacing: PPSpace.xxs) {
            Image(systemName: eyebrowSymbol)
                .font(.system(size: 9, weight: .bold))

            Text(eyebrow)
                .font(HomeFont.bold(11))
        }
        .foregroundStyle(Color.ppPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.84)
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, 4)
        .frame(minHeight: 24)
        .background(
            Color.ppPrimary.opacity(
                colorScheme == .dark ? 0.18 : 0.12
            ),
            in: Capsule()
        )
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    Color.ppPrimary.opacity(
                        colorScheme == .dark ? 0.16 : 0.10
                    )
                )
                .overlay {
                    Circle().strokeBorder(borderColor, lineWidth: 1)
                }

            avatarContent
                .frame(width: 64, height: 64)
                .background(
                    Color.ppSurface.opacity(
                        colorScheme == .dark ? 0.10 : 0.70
                    ),
                    in: Circle()
                )
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(
                        Color.white.opacity(
                            colorScheme == .dark ? 0.10 : 0.55
                        ),
                        lineWidth: 1.5
                    )
                }
        }
        .frame(width: 84, height: 84)
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
                contentMode: .scaleAspectFill,
                cacheKey: pet.id,
                displaySize: CGSize(width: 68, height: 68)
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

    private var metaRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    metaChip(metaPrimary, symbol: metaPrimarySymbol, emphasized: true)
                    metaChip(metaSecondary, symbol: metaSecondarySymbol, emphasized: false)
                }
            } else {
                HStack(spacing: PPSpace.sm) {
                    metaChip(metaPrimary, symbol: metaPrimarySymbol, emphasized: true)
                    metaChip(metaSecondary, symbol: metaSecondarySymbol, emphasized: false)
                }
            }
        }
    }

    private func metaChip(
        _ text: String,
        symbol: String,
        emphasized: Bool
    ) -> some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(HomeFont.medium(11))
        }
        .foregroundStyle(
            emphasized ? Color.ppTextPrimary : Color.ppTextSecondary
        )
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(.horizontal, PPSpace.sm)
        .padding(.vertical, 6)
        .background(
            Color.ppSecondarySurface.opacity(
                colorScheme == .dark ? 0.50 : 0.70
            ),
            in: Capsule()
        )
    }

    private var ctaView: some View {
        HStack(spacing: PPSpace.sm) {
            Text(ctaTitle)
                .font(HomeFont.bold(13))
                .foregroundStyle(Color.ppPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: PPSpace.sm)

            Image(systemName: forwardSymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PPSpace.md)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 52 : 44,
            alignment: .center
        )
        .background(
            Color.ppPrimary.opacity(colorScheme == .dark ? 0.16 : 0.10),
            in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .strokeBorder(
                    Color.ppPrimary.opacity(colorScheme == .dark ? 0.22 : 0.16),
                    lineWidth: 1
                )
        }
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

    private var cardMinHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 312
        }
        return horizontalSizeClass == .regular ? 248 : 232
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: UnitPoint(x: 0, y: 0),
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        if isLoading {
            return colorScheme == .dark
                ? [Color.ppSecondarySurface, Color.ppSurface.opacity(0.92)]
                : [Color.ppSurface, Color.ppSecondarySurface]
        }

        if errorMessage != nil {
            return colorScheme == .dark
                ? [Color.ppCard, Color.ppError.opacity(0.14)]
                : [Color.ppSurface, Color.ppError.opacity(0.08)]
        }

        if defaultPet != nil {
            return colorScheme == .dark
                ? [Color.ppCard, Color.ppPrimary.opacity(0.18)]
                : [Color.ppSurface, Color.ppPrimary.opacity(0.10)]
        }

        if hasProfilesWithoutDefault {
            return colorScheme == .dark
                ? [Color.ppCard, Color.ppPrimary.opacity(0.14)]
                : [Color.ppSurface, Color.ppPrimary.opacity(0.07)]
        }

        return colorScheme == .dark
            ? [Color.ppCard, Color.ppPrimary.opacity(0.12)]
            : [Color.ppSurface, Color.ppWarmPorcelain]
    }

    private var accentGlow: Color {
        Color.ppPrimary.opacity(colorScheme == .dark ? 0.18 : 0.14)
    }

    private var borderColor: Color {
        contrast == .increased
            ? Color.ppTextPrimary.opacity(0.45)
            : Color.ppBorder.opacity(0.10)
    }

    private var eyebrowSymbol: String {
        if isLoading { return "arrow.triangle.2.circlepath" }
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        if defaultPet?.isDefault == true { return "star.fill" }
        return "pawprint.fill"
    }

    private var metaPrimarySymbol: String {
        if isLoading { return "arrow.triangle.2.circlepath" }
        if errorMessage != nil { return "arrow.clockwise" }
        if defaultPet != nil { return "syringe.fill" }
        if hasProfilesWithoutDefault { return "pawprint.fill" }
        return "syringe.fill"
    }

    private var metaSecondarySymbol: String {
        if isLoading { return "heart.text.square.fill" }
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        if defaultPet != nil { return "pawprint.fill" }
        if hasProfilesWithoutDefault { return "hand.tap.fill" }
        return "bell.badge.fill"
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

private enum HomeQuickActionTone {
    static let lightSurfaceOpacity = 0.075
    static let darkSurfaceOpacity = 0.15

    static func accent(for action: HomePriorityAction) -> Color {
        switch action.id {
        case "shop":
            // Shopping: a warmer, grounded rose.
            return .ppQuickActionShopping
        case "pet":
            // Animals: a quieter magenta-lilac.
            return .ppQuickActionAnimals
        case "pharmacy":
            // Services: muted cyan.
            return .ppQuickActionServices
        case "vet":
            // Community: pale, composed blue.
            return .ppQuickActionCommunity
        case "ads":
            // Adoption: warm peach.
            return .ppQuickActionAdoption
        default:
            return Color(uiColor: action.accent)
        }
    }
}

struct HomePriorityGrid: View {
    let actions: [HomePriorityAction]
    let featuredPet: HomePetModel?
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline)
    private var compactCardHeight: CGFloat = 128

    private enum Layout {
        static let columnSpacing = PPSpace.md
        static let cardSpacing = PPSpace.sm
        static let featuredCircleSize: CGFloat = 108
        static let featuredCircleTopInset = PPSpace.sm
        static let featuredCardWidth: CGFloat = 148
    }

    private var compactSectionHeight: CGFloat {
        (compactCardHeight * 2) + Layout.cardSpacing
    }

    private var featuredAction: HomePriorityAction? {
        actions.first(where: { $0.id == "pet" }) ?? actions.first
    }

    private var secondaryActions: [HomePriorityAction] {
        let items = actions.filter { $0.id != "pet" }
        if items.count >= 4 {
            return Array(items.prefix(4))
        }
        return items
    }

    var body: some View {
        VStack(spacing: PPSpace.md) {
            headerView

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: PPSpace.sm) {
                    if let featured = featuredAction {
                        HomeFeaturedPetCard(
                            action: featured,
                            pet: featuredPet,
                            regularWidth: Layout.featuredCardWidth,
                            compactHeight: compactSectionHeight,
                            regularCircleSize: Layout.featuredCircleSize,
                            circleInset: Layout.featuredCircleTopInset,
                            onSelect: onSelect
                        )
                    }
                    ForEach(secondaryActions) { action in
                        HomeSecondaryActionCard(
                            action: action,
                            compactHeight: compactCardHeight,
                            onSelect: onSelect
                        )
                    }
                }
            } else {
                HStack(
                    alignment: .top,
                    spacing: Layout.columnSpacing
                ) {
                    if let featured = featuredAction {
                        HomeFeaturedPetCard(
                            action: featured,
                            pet: featuredPet,
                            regularWidth: Layout.featuredCardWidth,
                            compactHeight: compactSectionHeight,
                            regularCircleSize: Layout.featuredCircleSize,
                            circleInset: Layout.featuredCircleTopInset,
                            onSelect: onSelect
                        )
                        .frame(width: Layout.featuredCardWidth)
                        .modifier(HomeScrollCellReveal(ordinal: 0))
                    }

                    secondaryGrid
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: compactSectionHeight)
            }
        }
    }

    private var secondaryGrid: some View {
        let rows: [[(index: Int, action: HomePriorityAction)]] = {
            var result: [[(index: Int, action: HomePriorityAction)]] = []
            var index = 0
            let enumerated = Array(secondaryActions.enumerated())
            while index < enumerated.count {
                let end = index + 2
                let sliceEnd = end <= enumerated.count ? end : enumerated.count
                result.append(Array(enumerated[index..<sliceEnd].map { ($0.offset, $0.element) }))
                index = end
            }
            return result
        }()

        return VStack(spacing: Layout.cardSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Layout.cardSpacing) {
                    ForEach(row, id: \.action.id) { item in
                        HomeSecondaryActionCard(
                            action: item.action,
                            compactHeight: compactCardHeight,
                            onSelect: onSelect
                        )
                        .frame(maxWidth: .infinity)
                        .modifier(HomeScrollCellReveal(ordinal: item.index + 1))
                    }
                    if row.count == 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            HStack(spacing: PPSpace.sm) {
                Text(
                    HomeModelAdapter.localized(
                        "home_pulse_priority_title",
                        fallback: "خطوتك التالية"
                    )
                )
                .font(HomeFont.bold(24))
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)

                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.homeBrand)
                    .accessibilityHidden(true)
            }

            Text(
                HomeModelAdapter.localized(
                    "home_pulse_priority_subtitle",
                    fallback: "كل ما يحتاجه حيوانك في مكان واحد"
                )
            )
            .font(HomeFont.subheadline())
            .foregroundStyle(Color.homeTextSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct HomeFeaturedPetCard: View {
    let action: HomePriorityAction
    let pet: HomePetModel?
    let regularWidth: CGFloat
    let compactHeight: CGFloat
    let regularCircleSize: CGFloat
    let circleInset: CGFloat
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var loadedPetImageIdentity: String?

    private var animationHaloSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 132 : regularCircleSize
    }

    private var animationViewSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 204 : 168
    }

    private var regularCTAWidth: CGFloat {
        max(regularWidth - (PPSpace.sm * 2), 44)
    }

    private var subtitleColor: Color {
        Color.homeTextPrimary.opacity(
            contrast == .increased
                ? 0.92
                : (colorScheme == .dark ? 0.84 : 0.76)
        )
    }

    private var actionAccent: Color {
        HomeQuickActionTone.accent(for: action)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.hero,
            style: .continuous
        )
    }

    private var petImageURL: String? {
        let value = pet?.imageURL?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private var petImageIdentity: String? {
        guard let pet, let petImageURL else { return nil }
        return "\(pet.id)|\(petImageURL)"
    }

    var body: some View {
        Button {
            onSelect(action)
        } label: {
            VStack(spacing: 0) {
                animationArea
                    .padding(.top, circleInset)

                VStack(spacing: PPSpace.xxs) {
                    Text(action.title)
                        .font(HomeFont.bold(20))
                        .foregroundStyle(Color.homeTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(action.subtitle)
                        .font(HomeFont.medium(14))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.93)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, PPSpace.sm)

                Spacer(minLength: PPSpace.xs)

                HStack(spacing: PPSpace.sm) {
                    Text(
                        HomeModelAdapter.localized(
                            "home_pulse_manage_pet_cta",
                            fallback: "إدارة حيواني"
                        )
                    )
                    .font(HomeFont.bold(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .bold))
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(
                    width: dynamicTypeSize.isAccessibilitySize
                        ? nil
                        : regularCTAWidth
                )
                .frame(minHeight: 44)
                .background(
                    LinearGradient(
                        colors: [
                            actionAccent.opacity(0.88),
                            actionAccent,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(
                    color: actionAccent.opacity(
                        colorScheme == .dark ? 0.18 : 0.24
                    ),
                    radius: 7,
                    y: 4
                )
                .padding(.horizontal, PPSpace.sm)
                .padding(.bottom, PPSpace.sm)
            }
            .frame(maxWidth: .infinity)
            .frame(
                width: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : regularWidth
            )
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize
                    ? 328
                    : compactHeight
            )
            .frame(
                height: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : compactHeight
            )
            .background {
                ZStack {
                    cardShape.fill(Color.homeRaisedSurface)
                    cardShape.fill(
                        actionAccent.opacity(
                            colorScheme == .dark
                                ? HomeQuickActionTone.darkSurfaceOpacity
                                : HomeQuickActionTone.lightSurfaceOpacity
                        )
                    )
                }
            }
            .overlay {
                cardShape.stroke(
                    actionAccent.opacity(
                        contrast == .increased
                            ? 0.58
                            : (colorScheme == .dark ? 0.34 : 0.22)
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .overlay(alignment: .topLeading) {
                pawBadge
                    .padding(PPSpace.md)
            }
            .shadow(
                color: actionAccent.opacity(
                    colorScheme == .dark ? 0.10 : 0.12
                ),
                radius: 14,
                y: 7
            )
            .contentShape(cardShape)
        }
        .buttonStyle(HomeCardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }

    private var animationArea: some View {
        ZStack {
            Circle()
                .fill(
                    actionAccent.opacity(
                        colorScheme == .dark ? 0.19 : 0.12
                    )
                )
                .overlay {
                    Circle().stroke(
                        actionAccent.opacity(
                            contrast == .increased ? 0.48 : 0.16
                        ),
                        lineWidth: contrast == .increased ? 1.5 : 0.8
                    )
                }
                .frame(
                    width: animationHaloSize,
                    height: animationHaloSize
                )

            if petImageIdentity == nil ||
                loadedPetImageIdentity != petImageIdentity {
                fallbackPetArtwork
            }

            if let petImageURL, let petImageIdentity {
                petPhoto(
                    urlString: petImageURL,
                    identity: petImageIdentity
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: animationHaloSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fallbackPetArtwork: some View {
        if reduceMotion {
            Image("pawprint")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(actionAccent)
                .frame(
                    width: animationHaloSize * 0.66,
                    height: animationHaloSize * 0.66
                )
        } else {
            HomeHeroLottieRepresentable(
                animationName: "LottieAnimations/Loader cat.json",
                loadsFromFirebase: true,
                playbackEnabled: true
            )
            .frame(
                width: animationViewSize,
                height: animationViewSize
            )
            .clipShape(Circle())
        }
    }

    private func petPhoto(
        urlString: String,
        identity: String
    ) -> some View {
        AppRemoteImage(
            urlString: urlString,
            cacheKey: "home-priority-pet|\(identity)",
            displaySize: CGSize(
                width: animationHaloSize,
                height: animationHaloSize
            ),
            contentMode: .fill,
            retryCount: 2,
            fadeDuration: 0.20,
            showsRetryAction: false,
            onImageLoaded: { _ in
                DispatchQueue.main.async {
                    loadedPetImageIdentity = identity
                }
            }
        ) {
            Color.clear
        } failurePlaceholder: {
            Color.clear
        }
        .frame(
            width: animationHaloSize,
            height: animationHaloSize
        )
        .clipShape(Circle())
        .overlay {
            Circle().stroke(
                Color.homeRaisedSurface.opacity(
                    contrast == .increased ? 1 : 0.88
                ),
                lineWidth: contrast == .increased ? 2.5 : 2
            )
        }
        .id(identity)
    }

    private var pawBadge: some View {
        Image("pawsmall")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(actionAccent)
            .frame(width: 38, height: 38)
            .background(Color.homeRaisedSurface.opacity(0.8), in: Circle())
            .overlay {
                Circle().stroke(
                    actionAccent.opacity(
                        contrast == .increased ? 0.48 : 0.14
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
            .shadow(
                color: actionAccent.opacity(0.12),
                radius: 6,
                y: 3
            )
            .accessibilityHidden(true)
    }
}

private struct HomeSecondaryActionCard: View {
    let action: HomePriorityAction
    let compactHeight: CGFloat
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
    }

    private var subtitleColor: Color {
        Color.homeTextPrimary.opacity(
            contrast == .increased
                ? 0.92
                : (colorScheme == .dark ? 0.84 : 0.76)
        )
    }

    var body: some View {
        Button {
            onSelect(action)
        } label: {
            cardContent
            .frame(maxWidth: .infinity)
            .frame(
                minHeight: dynamicTypeSize.isAccessibilitySize
                    ? 92
                    : compactHeight
            )
            .frame(
                height: dynamicTypeSize.isAccessibilitySize
                    ? nil
                    : compactHeight
            )
            .background {
                ZStack {
                    cardShape.fill(Color.homeRaisedSurface)
                    cardShape.fill(
                        accentColor.opacity(
                            colorScheme == .dark
                                ? HomeQuickActionTone.darkSurfaceOpacity
                                : HomeQuickActionTone.lightSurfaceOpacity
                        )
                    )
                }
            }
            .overlay {
                cardShape.stroke(
                    accentColor.opacity(
                        contrast == .increased
                            ? 0.62
                            : (colorScheme == .dark ? 0.32 : 0.17)
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
            .shadow(
                color: Color.black.opacity(
                    colorScheme == .dark ? 0.16 : 0.045
                ),
                radius: 8,
                y: 4
            )
            .contentShape(cardShape)
        }
        .buttonStyle(HomeCardPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }

    @ViewBuilder
    private var cardContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: PPSpace.md) {
                actionIcon(size: 44)

                actionCopy

                Spacer(minLength: PPSpace.xs)

                directionIndicator(size: 32)
            }
            .padding(PPSpace.md)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: PPSpace.xs) {
                    actionIcon(size: 38)

                    Spacer(minLength: 0)

                    directionIndicator(size: 26)
                }

                Spacer(minLength: PPSpace.xs)

                actionCopy
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.top, PPSpace.md)
            .padding(.bottom, PPSpace.base)
        }
    }

    private var actionCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(action.title)
                .font(HomeFont.bold(18))
                .foregroundStyle(Color.homeTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.76)

            Text(action.subtitle)
                .font(HomeFont.medium(14))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.93)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionIcon(size: CGFloat) -> some View {
        Image(systemName: resolvedSymbol)
            .font(
                .system(
                    size: dynamicTypeSize.isAccessibilitySize ? 18 : 16,
                    weight: .bold
                )
            )
            .foregroundStyle(accentColor)
            .frame(width: size, height: size)
            .background(
                accentColor.opacity(
                    colorScheme == .dark ? 0.20 : 0.11
                ),
                in: RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PPCorner.small,
                    style: .continuous
                )
                .stroke(
                    accentColor.opacity(
                        contrast == .increased ? 0.56 : 0.12
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
            }
            .accessibilityHidden(true)
    }

    private func directionIndicator(size: CGFloat) -> some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(accentColor)
            .flipsForRightToLeftLayoutDirection(true)
            .frame(width: size, height: size)
            .background(
                Color.homeRaisedSurface.opacity(
                    colorScheme == .dark ? 0.72 : 0.90
                ),
                in: Circle()
            )
            .overlay {
                Circle().stroke(
                    accentColor.opacity(
                        contrast == .increased ? 0.52 : 0.13
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
            }
            .accessibilityHidden(true)
    }

    private var resolvedSymbol: String {
        switch action.id {
        case "shop": return "bag.fill"
        case "ads": return "heart.fill"
        case "pharmacy": return "pills.fill"
        case "vet": return "cross.case.fill"
        default: return action.systemImage
        }
    }

    private var accentColor: Color {
        HomeQuickActionTone.accent(for: action)
    }
}

private struct HomeCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct HomeMainKindShelfEntrance: ViewModifier {
    let isPresented: Bool
    let ordinal: Int
    let isAllCategory: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        // Driven by Home's shared initial phase, never cell onAppear. Late
        // lazy cells therefore stay still during horizontal scrolling.
        content
            .scaleEffect(
                isStaged ? stagedScale : 1,
                anchor: semanticAnchor
            )
            .rotation3DEffect(
                .degrees(isStaged ? stagedYaw : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: semanticAnchor,
                perspective: 0.72
            )
            .rotationEffect(
                .degrees(isStaged ? stagedRoll : 0),
                anchor: semanticAnchor
            )
            .offset(
                x: isStaged ? stagedHorizontalTravel : 0,
                y: isStaged ? stagedArcHeight : 0
            )
            .animation(entranceAnimation, value: isPresented)
    }

    private var isStaged: Bool {
        !isPresented && !reduceMotion
    }

    private var cappedOrdinal: Int {
        min(max(ordinal, 0), 4)
    }

    private var tier: CGFloat {
        CGFloat(cappedOrdinal)
    }

    private var semanticSign: CGFloat {
        layoutDirection == .rightToLeft ? -1 : 1
    }

    private var semanticAnchor: UnitPoint {
        UnitPoint(
            x: layoutDirection == .rightToLeft ? 1 : 0,
            y: 0.74
        )
    }

    private var stagedScale: CGFloat {
        if isAllCategory { return 0.965 }
        return max(0.916, 0.946 - (tier * 0.0075))
    }

    private var stagedHorizontalTravel: CGFloat {
        let base: CGFloat = isAllCategory ? 7 : 10
        return semanticSign * (base + (tier * 6))
    }

    private var stagedArcHeight: CGFloat {
        switch cappedOrdinal {
        case 0: return 3
        case 1: return 7
        case 2: return 11
        case 3: return 8
        default: return 4
        }
    }

    private var stagedYaw: Double {
        let base = isAllCategory ? 2.2 : 3.4
        return Double(semanticSign) * (base + (Double(tier) * 0.75))
    }

    private var stagedRoll: Double {
        let base = isAllCategory ? -0.65 : -1.15
        return Double(semanticSign) * (base + (Double(tier) * 0.52))
    }

    private var entranceAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .spring(
            response: 0.50,
            dampingFraction: 0.72,
            blendDuration: 0.07
        )
        .delay(0.02 + (Double(cappedOrdinal) * 0.045))
    }
}

@available(iOS 15.0, *)
struct HomeCategoryRail: View {
    let categories: [HomeCategoryModel]
    let selectedID: Int?
    let entrancePresented: Bool
    let onSelect: (HomeCategoryModel?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isExpanded = false
    @State private var viewportWidth: CGFloat = 0

    private enum RailLayout {
        static let cellSpacing = PPSpace.md
        static let shadowTopInset = PPSpace.md
        static let shadowBottomInset = PPSpace.lg
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPSectionHeaderSwiftUIRepresentable(
                title: HomeModelAdapter.localized(
                    "home_pulse_categories_title",
                    fallback: "Explore by pet"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_categories_subtitle",
                    fallback: "The selected species shapes relevant results"
                ),
                actionTitle: layoutActionTitle,
                action: toggleLayout,
                sectionRawValue: 5,
                isExpanded: isExpanded
            )
            .padding(.horizontal, PPSpace.screenMargin * 0.5)

            if isExpanded {
                expandedGrid
                    .transition(layoutTransition)
            } else {
                horizontalRail
                    .transition(layoutTransition)
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateViewportWidth(geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { width in
                        updateViewportWidth(width)
                    }
            }
        }
    }

    private var horizontalRail: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: RailLayout.cellSpacing) {
                        categoryCell(
                            nil,
                            entranceOrdinal: 0,
                            size: itemSize
                        )
                        .id(allCategoryScrollID)

                        ForEach(
                            Array(categories.enumerated()),
                            id: \.element.id
                        ) { index, category in
                            categoryCell(
                                category,
                                entranceOrdinal: index + 1,
                                size: itemSize
                            )
                            .id(scrollID(for: category))
                        }
                    }
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.top, RailLayout.shadowTopInset)
                    .padding(.bottom, RailLayout.shadowBottomInset)
                }
                .onAppear {
                    proxy.scrollTo(
                        selectedScrollID,
                        anchor: semanticLeadingAnchor(
                            viewportWidth: geometry.size.width
                        )
                    )
                }
            }
        }
        .frame(
            height: itemSize.height
                + RailLayout.shadowTopInset
                + RailLayout.shadowBottomInset
        )
    }

    private var expandedGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            alignment: .leading,
            spacing: RailLayout.cellSpacing
        ) {
            responsiveGridCell(
                nil,
                entranceOrdinal: 0
            )
            .id(allCategoryScrollID)

            ForEach(
                Array(categories.enumerated()),
                id: \.element.id
            ) { index, category in
                responsiveGridCell(
                    category,
                    entranceOrdinal: index + 1
                )
                .id(scrollID(for: category))
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.xs)
    }

    private var gridColumns: [GridItem] {
        let fixedCardWidth = itemSize.width
        return [
            GridItem(
                .adaptive(
                    minimum: fixedCardWidth,
                    maximum: fixedCardWidth
                ),
                spacing: RailLayout.cellSpacing,
                alignment: .top
            ),
        ]
    }

    private var layoutActionTitle: String {
        HomeModelAdapter.localized(
            isExpanded ? "ShowLess" : "ShowAll",
            fallback: isExpanded ? "Show less" : "Show all"
        )
    }

    private var layoutTransition: AnyTransition {
        .opacity.combined(
            with: .scale(
                scale: 0.985,
                anchor: .top
            )
        )
    }

    private func toggleLayout() {
        let update = {
            isExpanded.toggle()
        }
        guard !reduceMotion else {
            update()
            return
        }
        withAnimation(
            .spring(
                response: 0.46,
                dampingFraction: 0.86,
                blendDuration: 0.08
            ),
            update
        )
    }

    private var allCategoryScrollID: String {
        "home-main-kind-all"
    }

    private var selectedScrollID: String {
        guard let selectedID,
              let category = categories.first(where: {
                  HomeModelAdapter.mainKindID($0.raw) == selectedID
              }) else {
            return allCategoryScrollID
        }
        return scrollID(for: category)
    }

    private func semanticLeadingAnchor(
        viewportWidth: CGFloat
    ) -> UnitPoint {
        let availableWidth = max(viewportWidth - itemSize.width, 1)
        let insetFraction = min(
            max(PPSpace.screenMargin / availableWidth, 0),
            0.5
        )
        return UnitPoint(
            x: layoutDirection == .rightToLeft
                ? 1 - insetFraction
                : insetFraction,
            y: 0.5
        )
    }

    private func scrollID(for category: HomeCategoryModel) -> String {
        "home-main-kind-\(category.id)"
    }

    @ViewBuilder
    private func categoryCell(
        _ category: HomeCategoryModel?,
        entranceOrdinal: Int,
        size: CGSize
    ) -> some View {
        let categoryID = category.map {
            HomeModelAdapter.mainKindID($0.raw)
        }
        HomeMainKindCellRepresentable(
            category: category,
            selected: category == nil
                ? selectedID == nil
                : categoryID == selectedID,
            size: size,
            onSelect: {
                onSelect(category)
            }
        )
        .frame(width: size.width, height: size.height)
        .modifier(
            HomeMainKindShelfEntrance(
                isPresented: entrancePresented,
                ordinal: entranceOrdinal,
                isAllCategory: category == nil
            )
        )
    }

    private func responsiveGridCell(
        _ category: HomeCategoryModel?,
        entranceOrdinal: Int
    ) -> some View {
        GeometryReader { geometry in
            categoryCell(
                category,
                entranceOrdinal: entranceOrdinal,
                size: geometry.size
            )
        }
        .frame(height: itemSize.height)
    }

    private var itemSize: CGSize {
        let width = viewportWidth > 1 ? viewportWidth : 390
        if dynamicTypeSize.isAccessibilitySize {
            return CGSize(
                width: width < 375 ? 116 : 118,
                height: 148
            )
        }
        if width >= 700 {
            return CGSize(width: 114, height: 184)
        }
        if width >= 430 {
            return CGSize(width: 112, height: 143)
        }
        if width < 375 {
            return CGSize(width: 104, height: 130)
        }
        return CGSize(width: 108, height: 132)
    }

    private func updateViewportWidth(_ width: CGFloat) {
        guard width > 1, abs(viewportWidth - width) > 0.5 else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewportWidth = width
        }
    }
}

private struct HomeMainKindCellRepresentable: UIViewRepresentable {
    let category: HomeCategoryModel?
    let selected: Bool
    let size: CGSize
    let onSelect: () -> Void

    func makeUIView(context: Context) -> PPMainKindsCell {
        PPMainKindsCell(
            frame: CGRect(origin: .zero, size: size)
        )
    }

    func updateUIView(_ cell: PPMainKindsCell, context: Context) {
        if cell.bounds.size != size {
            cell.bounds = CGRect(origin: .zero, size: size)
        }
        cell.configure(
            withMainKind: category?.raw,
            isAll: category == nil,
            selected: selected,
            restoredSelectionAppearance: false
        )
        cell.onSelect = { _, _ in
            onSelect()
        }
    }

    static func dismantleUIView(_ cell: PPMainKindsCell, coordinator: Void) {
        cell.onSelect = nil
    }
}

/// Smooth animated linear progress bar indicator for HomeOrderCard.
/// Animates progress fill with spring dynamics and respects native layout direction and Reduce Motion.
private struct HomeAnimatedOrderProgress: View {
    let progress: Double
    let accentColor: Color
    let borderColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private let barHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let fillWidth = max(0, min(totalWidth * animatedProgress, totalWidth))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(borderColor.opacity(0.38))
                    .frame(height: barHeight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.75),
                                accentColor,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: barHeight)
            }
        }
        .frame(height: barHeight)
        .onAppear {
            animateToTarget(progress)
        }
        .onChange(of: progress) { newProgress in
            animateToTarget(newProgress)
        }
    }

    private func animateToTarget(_ target: Double) {
        if reduceMotion {
            animatedProgress = target
        } else {
            if animatedProgress == 0 {
                DispatchQueue.main.async {
                    withAnimation(
                        .spring(
                            response: 0.72,
                            dampingFraction: 0.82,
                            blendDuration: 0.08
                        )
                    ) {
                        animatedProgress = target
                    }
                }
            } else {
                withAnimation(
                    .spring(
                        response: 0.62,
                        dampingFraction: 0.82,
                        blendDuration: 0.08
                    )
                ) {
                    animatedProgress = target
                }
            }
        }
    }
}

@available(iOS 15.0, *)
struct HomeOrderCard: View {
    let order: HomeOrderModel
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPSectionHeaderSwiftUIRepresentable(
                title: HomeModelAdapter.localized(
                    "home_pulse_current_order_title",
                    fallback: "Current order"
                ),
                subtitle: order.reference,
                sectionRawValue: 2,
                showsAction: false,
                headingAccentColor: statusAccentUIColor
            )
            .padding(.horizontal, PPSpace.screenMargin * 0.5)

            Button(action: onTap) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityContent
                    } else {
                        compactContent
                    }
                }
                .padding(PPSpace.base)
                .background {
                    cardShape.fill(
                        LinearGradient(
                            colors: [
                                statusStrongSurface.opacity(
                                    colorScheme == .dark ? 0.86 : 0.70
                                ),
                                statusSurface,
                                Color.homeRaisedSurface,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .overlay {
                    cardShape.stroke(
                        statusBorder,
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
                }
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(statusAccent)
                        .frame(width: 4)
                        .padding(.vertical, PPSpace.lg)
                        .padding(.leading, PPSpace.xs)
                }
                .clipShape(cardShape)
                .shadow(
                    color: statusAccent.opacity(
                        contrast == .increased
                            ? 0
                            : (colorScheme == .dark ? 0.05 : 0.07)
                    ),
                    radius: contrast == .increased ? 0 : 8,
                    y: contrast == .increased ? 0 : 3
                )
            }
            .buttonStyle(HomeCardPressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(
                HomeModelAdapter.localized(
                    "home_pulse_order_details_a11y",
                    fallback: "Opens order details"
                )
            )
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                statusGlyph
                statusCopy
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
                disclosureIndicator
            }

            statusProgress

            Divider()
                .overlay(statusBorder.opacity(0.72))
                .accessibilityHidden(true)

            orderSummary
        }
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                statusGlyph
                Spacer(minLength: PPSpace.sm)
                disclosureIndicator
            }

            statusCopy
            statusProgress

            Divider()
                .overlay(statusBorder.opacity(0.72))
                .accessibilityHidden(true)

            orderSummary
        }
    }

    private var statusCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(order.statusTitle)
                .font(HomeFont.title2())
                .foregroundStyle(Color.homeTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(order.statusHint)
                .font(HomeFont.subheadline())
                .foregroundStyle(Color.homeTextSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusProgress: some View {
        HomeAnimatedOrderProgress(
            progress: resolvedProgress,
            accentColor: statusAccent,
            borderColor: statusBorder
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var orderSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                if !order.amount.isEmpty {
                    amountLabel
                }
                itemCountLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                if !order.amount.isEmpty {
                    amountLabel

                    Circle()
                        .fill(statusAccent)
                        .frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                }

                itemCountLabel
                Spacer(minLength: 0)
            }
        }
    }

    private var amountLabel: some View {
        Text(order.amount)
            .font(HomeFont.bold(16))
            .foregroundStyle(Color.homeTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var itemCountLabel: some View {
        Text(
            String(
                format: HomeModelAdapter.localized(
                    "home_pulse_order_items",
                    fallback: "%d items"
                ),
                order.itemCount
            )
        )
        .font(HomeFont.footnote())
        .foregroundStyle(Color.homeTextSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(statusStrongSurface)

            statusSymbol
                .foregroundStyle(statusAccent)
                .frame(width: 27, height: 27)
        }
        .frame(width: 60, height: 60)
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .stroke(
                    statusBorder,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusSymbol: some View {
        if UIImage(systemName: statusSymbolName) != nil {
            Image(systemName: statusSymbolName)
                .resizable()
                .scaledToFit()
        } else if UIImage(named: statusSymbolName) != nil {
            Image(statusSymbolName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else if UIImage(systemName: order.symbol) != nil {
            Image(systemName: order.symbol)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
        }
    }

    private var disclosureIndicator: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(statusAccent)
            .flipsForRightToLeftLayoutDirection(true)
            .frame(width: 42, height: 42)
            .background(statusStrongSurface, in: Circle())
            .overlay {
                Circle().stroke(
                    statusBorder,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
            .accessibilityHidden(true)
    }

    private var resolvedProgress: Double {
        min(max(order.progress, 0), 1)
    }

    private var statusTraits: UITraitCollection {
        UITraitCollection(
            userInterfaceStyle: colorScheme == .dark ? .dark : .light
        )
    }

    private var statusAccentUIColor: UIColor {
        // PPOrderStatusAppearance remains the single visual-status authority.
        PPOrderStatusAccentColorForKey(order.statusKey)
    }

    private var statusAccent: Color {
        Color(uiColor: statusAccentUIColor)
    }

    private var statusSurface: Color {
        Color(uiColor: PPOrderStatusSurfaceColorForAccent(
            statusAccentUIColor,
            statusTraits
        ))
    }

    private var statusStrongSurface: Color {
        Color(uiColor: PPOrderStatusStrongSurfaceColorForAccent(
            statusAccentUIColor,
            statusTraits
        ))
    }

    private var statusBorder: Color {
        Color(uiColor: PPOrderStatusBorderColorForAccent(
            statusAccentUIColor,
            statusTraits
        ))
    }

    private var statusSymbolName: String {
        PPOrderStatusSymbolNameForKey(order.statusKey)
    }
}

@available(iOS 15.0, *)
struct HomeFeedSection: View {
    let section: HomeSectionModel
    let store: HomeStore
    let entrancePresented: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let thirdCardPeekFraction: CGFloat = 0.12

    private var cardRailHeight: CGFloat {
        328 + (PPSpace.xs * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            PPSectionHeaderSwiftUIRepresentable(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: section.seeAllTitle,
                action: section.seeAllTitle == nil
                    ? nil
                    : { store.seeAll(section.kind) },
                sectionRawValue: section.rawConfigSectionID
            )
            .padding(.horizontal, PPSpace.screenMargin * 0.5)

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
                            ForEach(
                                Array(cards.enumerated()),
                                id: \.element.id
                            ) { ordinal, card in
                                HomeUniversalCard(
                                    card: card,
                                    delegate: store.router.universalCardDelegate,
                                    onTap: { store.tapCard(card) },
                                    onQuantityChange: {
                                        store.setQuantity($0, for: card)
                                    },
                                    entrancePresented: entrancePresented,
                                    entranceOrdinal: ordinal
                                )
                                .frame(width: resolvedCardWidth)
                                .modifier(HomeScrollCellReveal(ordinal: ordinal))
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
                        : { store.seeAll(section.kind) }
                )
                .padding(.horizontal, PPSpace.screenMargin)
            case let .failed(title, message, retryTitle):
                HomeInlineState(
                    symbol: "arrow.clockwise.circle",
                    title: title,
                    message: message,
                    actionTitle: retryTitle,
                    action: { store.retry(section: section.kind) }
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
        let spacing = PPSpace.md
        let usesReadableSingleCard =
            dynamicTypeSize.isAccessibilitySize || viewportWidth < 350

        let standardWidth: CGFloat
        if usesReadableSingleCard {
            standardWidth = max(
                0,
                (availableWidth - spacing)
                    / (1 + thirdCardPeekFraction)
            )
        } else {
            standardWidth = max(
                0,
                (availableWidth - (spacing * 2))
                    / (2 + thirdCardPeekFraction)
            )
        }

        guard itemCount > 1 else { return standardWidth }

        if usesReadableSingleCard {
            return standardWidth
        }

        guard itemCount > 2 else {
            return max(0, (availableWidth - spacing) / 2)
        }

        // Leading margin + two complete cards + two gaps + 12% of the third.
        return standardWidth
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
                ForEach(Array(Self.skeletonIDs.enumerated()), id: \.element) { index, _ in
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
                    .overlay {
                        HomeSkeletonShimmer(phaseOffset: Double(index) * 0.18)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: PPCorner.card,
                                    style: .continuous
                                )
                            )
                    }
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

struct HomeRemoteImage: View {
    let urlString: String?
    let placeholder: UIImage?
    let contentMode: UIView.ContentMode
    var cacheKey: String? = nil
    var displaySize: CGSize? = nil

    var body: some View {
        AppRemoteImage(
            urlString: urlString,
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: swiftUIContentMode
        ) {
            placeholderView
        } failurePlaceholder: {
            placeholderView
        }
        .background(Color(uiColor: .ppSecondarySurface))
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var placeholderView: some View {
        if let placeholder {
            Image(uiImage: placeholder)
                .resizable()
                .aspectRatio(contentMode: swiftUIContentMode)
        } else {
            Color(uiColor: .ppSecondarySurface)
        }
    }

    private var swiftUIContentMode: ContentMode {
        contentMode == .scaleAspectFit ? .fit : .fill
    }
}

// MARK: - HomeView Horizontal Scroll Motion System

/// Cascade entrance for Pet Switcher pills.
/// Each pill rises from the leading edge with staggered scale, opacity, and
/// horizontal translation — creating a gentle wave that draws the eye across
/// the rail without demanding attention.
private struct HomePetPillCascade: ViewModifier {
    let ordinal: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || revealed ? 1 : 0)
            .scaleEffect(
                reduceMotion || revealed ? 1 : 0.92,
                anchor: semanticLeadingAnchor
            )
            .offset(
                x: reduceMotion || revealed
                    ? 0
                    : semanticSign * 14
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : .spring(
                        response: 0.44,
                        dampingFraction: 0.78,
                        blendDuration: 0.06
                    )
                    .delay(Double(cappedOrdinal) * 0.04),
                value: revealed
            )
            .onAppear {
                guard !revealed else { return }
                // Fire on the next run-loop so the staged pose is rendered
                // before the spring transition begins.
                DispatchQueue.main.async {
                    revealed = true
                }
            }
    }

    private var cappedOrdinal: Int { min(ordinal, 5) }

    private var semanticSign: CGFloat {
        layoutDirection == .rightToLeft ? 1 : -1
    }

    private var semanticLeadingAnchor: UnitPoint {
        layoutDirection == .rightToLeft
            ? UnitPoint(x: 1, y: 0.5)
            : UnitPoint(x: 0, y: 0.5)
    }
}

/// Scroll-triggered reveal for universal feed-section cards.
/// When a card lazy-loads during horizontal scrolling, it lifts gently from
/// below with a brief opacity ramp — making the appearance feel intentional
/// rather than abrupt. Cards already visible at layout time still benefit
/// from the one-shot entrance.
struct HomeScrollCellReveal: ViewModifier {
    let ordinal: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : 10)
            .scaleEffect(
                reduceMotion || appeared ? 1 : 0.97,
                anchor: .bottom
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : .spring(
                        response: 0.48,
                        dampingFraction: 0.84,
                        blendDuration: 0.06
                    )
                    .delay(Double(min(ordinal, 3)) * 0.035),
                value: appeared
            )
            .onAppear {
                guard !appeared else { return }
                DispatchQueue.main.async {
                    appeared = true
                }
            }
    }
}

/// Traveling shimmer overlay for skeleton placeholder cards.
/// A translucent gradient sweeps across the card surface to communicate
/// loading progress. Each card receives a phase offset so the wave
/// cascades across the rail rather than pulsing in unison.
private struct HomeSkeletonShimmer: View {
    let phaseOffset: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            GeometryReader { geometry in
                let shimmerWidth = geometry.size.width * 0.45
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.06),
                        Color.white.opacity(0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: shimmerWidth)
                .offset(x: -shimmerWidth + (phase * (geometry.size.width + shimmerWidth)))
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.6)
                        .repeatForever(autoreverses: false)
                        .delay(phaseOffset)
                    ) {
                        phase = 1
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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
