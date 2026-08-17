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

    static func semiBold(_ size: CGFloat) -> Font {
        .custom(
            "Beiruti-SemiBold",
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
    /// Resolved by `PPHomePresentationResolver`. `spotlight` gives search its own
    /// full-width lane in the command surface instead of a separate Home row.
    var searchProminence: PPHomeSearchProminence = .compact
    let searchAction: () -> Void
    let cartAction: () -> Void
    let locationAction: () -> Void
    var novaAction: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var commandControlHeight: CGFloat = 48

    private var showsLocationLane: Bool {
        state.config.titleViewMode == "location"
    }

    private var showsNova: Bool {
        !PPHomePresentationFlags.hidesNovaInCommandSurface
            && state.config.novaFloatingVisible
            && novaAction != nil
    }

    /// Search earns its own lane when the Console enables spotlight search or
    /// when accessibility text needs a calm vertical reflow.
    private var usesStackedSearchLane: Bool {
        showsLocationLane
            && (searchProminence == .spotlight || dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        commandContainer
            .padding(.horizontal, PPSpace.screenMargin + 1)
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

    /// The command surface is one unified pill. Its child buttons retain
    /// independent actions and semantics without drawing separate glass islands.
    @ViewBuilder
    private var commandContainer: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: PPSpace.md) {
                commandContent
                    .glassEffect(
                        .regular.tint(commandTint),
                        in: commandPillShape
                    )
                    .overlay {
                        commandPillShape.stroke(
                            commandBorder,
                            lineWidth: contrast == .increased ? 1.5 : 1
                        )
                    }
            }
        } else {
            fallbackCommandPill(commandContent)
        }
#else
        fallbackCommandPill(commandContent)
#endif
    }

    @ViewBuilder
    private var commandContent: some View {
        if usesStackedSearchLane {
            VStack(spacing: PPSpace.md) {
                HStack(spacing: PPSpace.md) {
                    locationButton
                    cartButtonWithTrailingRoom
                }
                HStack(spacing: PPSpace.md) {
                    searchField
                    novaButton
                }
            }
        } else if showsLocationLane {
            HStack(spacing: PPSpace.sm) {
                locationButton
                commandVerticalSeparator
                compactSearchButton
                if showsNova {
                    novaButton
                }
                commandVerticalSeparator
                cartButtonWithTrailingRoom
            }
        } else {
            HStack(spacing: PPSpace.sm) {
                searchField
                if showsNova {
                    novaButton
                }
                commandVerticalSeparator
                cartButtonWithTrailingRoom
            }
        }
    }

    /// Same lane pattern as search: an accent symbol, the live value, and a
    /// semantic-trailing disclosure on one token surface with one border rule.
    private var locationButton: some View {
        Button(action: locationAction) {
            HStack(spacing: PPSpace.md) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppAccentText)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(HomeModelAdapter.localized(
                        "home_pulse_location_context",
                        fallback: "Your area"
                    ))
                    .font(HomeFont.caption2())
                    .foregroundStyle(Color.homeTextSecondary)
                    .lineLimit(1)

                    Text(locationTitle)
                        .font(HomeFont.bold(15))
                        .foregroundStyle(Color.homeTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.homeTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: resolvedControlHeight)
            .contentShape(HomeCommandBar.controlShape)
        }
        .buttonStyle(commandButtonStyle)
        .accessibilityLabel(HomeModelAdapter.localized(
            "home_pulse_location_context",
            fallback: "Your area"
        ))
        .accessibilityValue(locationTitle)
    }

    private var compactSearchButton: some View {
        Button(action: searchAction) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.ppAccentText)
                .frame(
                    width: resolvedControlHeight,
                    height: resolvedControlHeight
                )
                .contentShape(HomeCommandBar.controlShape)
        }
        .buttonStyle(commandButtonStyle)
        .accessibilityLabel(HomeModelAdapter.localized(
            "home_pulse_search_a11y",
            fallback: "Search Pure Pets"
        ))
        .accessibilityHint(HomeModelAdapter.localized(
            "home_pulse_search_prompt",
            fallback: "Search products, pets, and services"
        ))
    }

    @ViewBuilder
    private var novaButton: some View {
        if showsNova, let novaAction {
            Button(action: novaAction) {
                HomeHeaderSparkleMotion()
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel(HomeModelAdapter.localized(
                "nova_empty_title",
                fallback: "Ask Nova"
            ))
            .accessibilityHint(HomeModelAdapter.localized(
                "nova_empty_subtitle",
                fallback: "Smart shopping assistant from Pure Pets"
            ))
        }
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

    /// The one Home search treatment: an accent magnifier, the live rotating
    /// suggestion, and a semantic-trailing chevron on a token surface. Text and
    /// symbol both resolve through measured tokens, so contrast is provable in
    /// light, dark, and Increased Contrast.
    private var searchField: some View {
        Button(action: searchAction) {
            HStack(spacing: PPSpace.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppAccentText)
                    .accessibilityHidden(true)

                HomeAnimatedSearchSuggestionView(isRTL: state.isRightToLeft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.homeTextSecondary)
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: resolvedControlHeight)
            .contentShape(HomeCommandBar.controlShape)
        }
        .buttonStyle(commandButtonStyle)
        .accessibilityLabel(
            HomeModelAdapter.localized(
                "home_pulse_search_a11y",
                fallback: "Search Pure Pets"
            )
        )
        .accessibilityHint(
            HomeModelAdapter.localized(
                "home_pulse_search_prompt",
                fallback: "Search products, pets, and services"
            )
        )
    }

    /// Legacy default used only by the optional Nova glyph owner. The visible
    /// location, search, and cart controls use `resolvedControlHeight`.
    static let controlSide: CGFloat = 52

    static var controlShape: Capsule {
        Capsule(style: .continuous)
    }

    private var commandPillShape: Capsule {
        Capsule(style: .continuous)
    }

    private var commandTint: Color {
        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.035)
    }

    private var commandBorder: Color {
        Color.homeBrand.opacity(
            contrast == .increased
                ? 0.5
                : (colorScheme == .dark ? 0.22 : 0.12)
        )
    }

    private var resolvedControlHeight: CGFloat {
        let maximum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 64 : 54
        return min(max(commandControlHeight + 2, 50), maximum)
    }

    private var commandSeparatorColor: Color {
        commandBorder.opacity(contrast == .increased ? 1 : 0.86)
    }

    private var commandVerticalSeparator: some View {
        Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: commandBorder.opacity(0), location: 0),
                        .init(color: commandSeparatorColor, location: 0.28),
                        .init(color: commandSeparatorColor, location: 0.72),
                        .init(color: commandBorder.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(
                width: contrast == .increased ? 1.5 : 1,
                height: max(
                    PPSpace.xl,
                    resolvedControlHeight - PPSpace.md
                )
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var cartButtonWithTrailingRoom: some View {
        cartButton
            .padding(.trailing, PPSpace.xs + PPSpace.xxs)
    }

    private var commandButtonStyle: HomeCommandButtonStyle {
        HomeCommandButtonStyle(reduceMotion: reduceMotion)
    }

    private func fallbackCommandPill<Content: View>(
        _ content: Content
    ) -> some View {
        content
            .background {
                if reduceTransparency {
                    commandPillShape.fill(Color.homeSurface)
                } else {
                    commandPillShape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            commandPillShape.fill(commandTint)
                        }
                }
            }
            .overlay {
                commandPillShape.stroke(
                    commandBorder,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            }
    }

    private struct HomeCommandButtonStyle: ButtonStyle {
        let reduceMotion: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(
                    configuration.isPressed
                        && !reduceMotion
                        ? 0.986
                        : 1
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: 0.16),
                    value: configuration.isPressed
                )
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

    /// Redesigned onto the command-surface vocabulary. The glyph stays neutral so
    /// brand colour is spent only on the badge, which is the one meaningful
    /// priority signal here. Count is also exposed as an accessibility value, so
    /// the state never depends on the badge alone.
    private var cartButton: some View {
        Button(action: cartAction) {
            Image(systemName: "cart.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(
                    width: resolvedControlHeight,
                    height: resolvedControlHeight
                )
                .contentShape(HomeCommandBar.controlShape)
                .overlay(alignment: .topTrailing) {
                if state.cartCount > 0 {
                    Text(state.cartCount > 99 ? "99+" : "\(state.cartCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, state.cartCount > 9 ? 5 : 0)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.ppPrimary, in: Capsule())
                        .overlay {
                            Capsule().stroke(Color.homeSurface, lineWidth: 2)
                        }
                        .padding(.top, PPSpace.xs)
                        .padding(.trailing, PPSpace.xs)
                        .accessibilityHidden(true)
                }
            }
            .frame(
                width: resolvedControlHeight,
                height: resolvedControlHeight
            )
            .contentShape(HomeCommandBar.controlShape)
        }
        .buttonStyle(commandButtonStyle)
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
                Color.ppSurfaceRaised.opacity(contrast == .increased ? 1 : 0.82),
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
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
                action: onEdit
            )
            .padding(.horizontal, PPSpace.screenMargin)

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
                // The pill shadow reaches ~28pt below its frame. Pre-iOS 17
                // this padding is the only room it has; from iOS 17 the scroll
                // clip is lifted so the elevation is never sliced.
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 8 : 6)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 18 : 16)
            }
            .contentMarginsCompat()
            .scrollShadowClipDisabledCompat()
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
                        Color.ppSurfaceRaised.opacity(
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
                        Circle().strokeBorder(Color.ppSurfaceRaised, lineWidth: 2)
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
            Image("pawsmall")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
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
                        Color.ppSurfaceRaised.opacity(
                            colorScheme == .dark ? 0.96 : 0.98
                        ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.ppSurfaceRaised)
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
            HomeHeroField(
                accent: surfaceAccent,
                increasedContrast: contrast == .increased,
                cornerGlowOpacityScale: 0.72
            )

            contentLayer
                .padding(PPSpace.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardMinHeight)
        .clipShape(cardShape)
        .overlay {
            HomeHeroBorder(
                accent: surfaceAccent,
                darkMode: colorScheme == .dark,
                increasedContrast: contrast == .increased
            )
        }
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
        Image("pawprint")
            .font(.system(size: 86, weight: .black))
            .foregroundStyle(
                Color.ppPrimary.opacity(
                    colorScheme == .dark ? 0.03 : 0.04
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .bottomTrailing)
            .padding(.trailing, -PPSpace.sm)
            .padding(.bottom, -PPSpace.sm)
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
                .padding(.top, PPSpace.sm)

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
                    Color.ppSurfaceRaised.opacity(
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
            Group {
                if UIImage(named: avatarSymbol) != nil {
                    Image(avatarSymbol)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: avatarSymbol)
                        .font(.system(size: 30, weight: .semibold))
                }
            }
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
            in: RoundedRectangle(cornerRadius: PPCorner.small + 4, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.small + 4, style: .continuous)
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
            return "pawprint"
        }
        return "sparkles"
    }
    //Image("pawprint")
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
        RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
    }

    private var surfaceAccent: Color {
        if errorMessage != nil {
            return Color.ppError
        }
        return Color.homeBrand
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
            return .ppAdoptionAccent
        case "pharmacy", "vet":
            return .ppCareAccent
        case "ads":
            return .ppAdoptionAccent
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
    private var compactCardHeight: CGFloat = 120

    private enum Layout {
        static let columnSpacing = PPSpace.md
        static let cardSpacing = PPSpace.sm
        static let featuredCircleTopInset = PPSpace.sm
        static let minimumFeaturedWidth: CGFloat = 104
        static let maximumFeaturedWidth: CGFloat = 148
        static let featuredWidthRatio: CGFloat = 0.38
        static let minimumFeaturedCircle: CGFloat = 80
        static let maximumFeaturedCircle: CGFloat = 100
        static let featuredCircleWidthRatio: CGFloat = 0.68
        static let maximumContentWidth: CGFloat = 488
    }

    private var compactSectionHeight: CGFloat {
        (compactCardHeight * 2) + Layout.cardSpacing
    }

    private var featuredAction: HomePriorityAction? {
        actions.first(where: { $0.id == "pet" })
    }

    private var secondaryActions: [HomePriorityAction] {
        let items = actions.filter { $0.id != "pet" }
        let limit = PPHomePresentationLimits.ecosystemLauncherSecondaryActions
        if items.count >= limit {
            return Array(items.prefix(limit))
        }
        return items
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                GeometryReader { proxy in
                    bentoLayout(availableWidth: proxy.size.width)
                }
                .frame(height: compactSectionHeight)
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(spacing: PPSpace.sm) {
            if let featured = featuredAction {
                HomeFeaturedPetCard(
                    action: featured,
                    pet: featuredPet,
                    regularWidth: nil,
                    compactHeight: compactSectionHeight,
                    regularCircleSize: Layout.maximumFeaturedCircle,
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
    }

    private func bentoLayout(availableWidth: CGFloat) -> some View {
        let contentWidth = min(
            availableWidth,
            Layout.maximumContentWidth
        )
        let featuredWidth = min(
            max(
                contentWidth * Layout.featuredWidthRatio,
                Layout.minimumFeaturedWidth
            ),
            Layout.maximumFeaturedWidth
        )
        let featuredCircle = min(
            max(
                featuredWidth * Layout.featuredCircleWidthRatio,
                Layout.minimumFeaturedCircle
            ),
            Layout.maximumFeaturedCircle
        )

        return HStack(
            alignment: .top,
            spacing: Layout.columnSpacing
        ) {
            if let featured = featuredAction {
                HomeFeaturedPetCard(
                    action: featured,
                    pet: featuredPet,
                    regularWidth: featuredWidth,
                    compactHeight: compactSectionHeight,
                    regularCircleSize: featuredCircle,
                    circleInset: Layout.featuredCircleTopInset,
                    onSelect: onSelect
                )
                .frame(width: featuredWidth)
            }

            secondaryGrid
                .frame(maxWidth: .infinity)
        }
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: compactSectionHeight)
    }

    private var secondaryGrid: some View {
        let firstRow = Array(secondaryActions.prefix(2))
        let secondRow = Array(secondaryActions.dropFirst(2).prefix(2))

        return VStack(spacing: Layout.cardSpacing) {
            secondaryRow(firstRow)

            if !secondRow.isEmpty {
                secondaryRow(secondRow)
            }
        }
    }

    private func secondaryRow(
        _ actions: [HomePriorityAction]
    ) -> some View {
        HStack(spacing: Layout.cardSpacing) {
            ForEach(actions) { action in
                HomeSecondaryActionCard(
                    action: action,
                    compactHeight: compactCardHeight,
                    onSelect: onSelect
                )
                .frame(maxWidth: .infinity)
            }

            if actions.count == 1 {
                Spacer(minLength: 0)
            }
        }
    }
}

struct HomeFeaturedCardShape: Shape {
    var cornerRadius: CGFloat = PPCorner.medium
    var topTrailingDelta: CGFloat = 12
    var isRightToLeft: Bool = false

    func path(in rect: CGRect) -> Path {
        let base = cornerRadius
        let topTrailingRadius = cornerRadius + topTrailingDelta

        let tl = isRightToLeft ? topTrailingRadius : base
        let tr = isRightToLeft ? base : topTrailingRadius
        let bl = base
        let br = base

        if #available(iOS 16.0, *) {
            return UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: base,
                    bottomLeading: base,
                    bottomTrailing: base,
                    topTrailing: topTrailingRadius
                ),
                style: .continuous
            )
            .path(in: rect)
        } else {
            let path = UIBezierPath()
            let minX = rect.minX
            let minY = rect.minY
            let maxX = rect.maxX
            let maxY = rect.maxY

            path.move(to: CGPoint(x: minX + tl, y: minY))
            path.addLine(to: CGPoint(x: maxX - tr, y: minY))
            path.addQuadCurve(to: CGPoint(x: maxX, y: minY + tr), controlPoint: CGPoint(x: maxX, y: minY))
            path.addLine(to: CGPoint(x: maxX, y: maxY - br))
            path.addQuadCurve(to: CGPoint(x: maxX - br, y: maxY), controlPoint: CGPoint(x: maxX, y: maxY))
            path.addLine(to: CGPoint(x: minX + bl, y: maxY))
            path.addQuadCurve(to: CGPoint(x: minX, y: maxY - bl), controlPoint: CGPoint(x: minX, y: maxY))
            path.addLine(to: CGPoint(x: minX, y: minY + tl))
            path.addQuadCurve(to: CGPoint(x: minX + tl, y: minY), controlPoint: CGPoint(x: minX, y: minY))
            path.close()
            return Path(path.cgPath)
        }
    }
}

struct HomeFeaturedPetCard: View {
    let action: HomePriorityAction
    let pet: HomePetModel?
    /// A fixed width preserves the legacy side-column geometry. `nil` lets the
    /// same card fill a phone-safe featured lane without compressing siblings.
    let regularWidth: CGFloat?
    let compactHeight: CGFloat
    let regularCircleSize: CGFloat
    let circleInset: CGFloat
    let onSelect: (HomePriorityAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var loadedPetImageIdentity: String?

    private var animationHaloSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 132 : regularCircleSize
    }

    private var animationViewSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? 204
            : animationHaloSize * 1.55
    }

    private var regularCTAWidth: CGFloat? {
        guard let regularWidth else { return nil }
        return max(regularWidth - (PPSpace.sm * 2), 44)
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

    private var cardShape: HomeFeaturedCardShape {
        HomeFeaturedCardShape(
            cornerRadius: PPCorner.medium,
            topTrailingDelta: 12,
            isRightToLeft: layoutDirection == .rightToLeft
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
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .minimumScaleFactor(0.82)

                    Text(action.subtitle)
                        .font(HomeFont.medium(14))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .minimumScaleFactor(0.93)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, PPSpace.md)
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
                    in: RoundedRectangle(
                        cornerRadius: PPCorner.small + 6,
                        style: .continuous
                    )
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
            .background(Color.homeSurface, in: cardShape)
            .clipShape(cardShape)
            .overlay {
                cardShape.stroke(
                    actionAccent.opacity(
                        contrast == .increased
                            ? 0.62
                            : (colorScheme == .dark ? 0.28 : 0.14)
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
            .overlay(alignment: .topLeading) {
                pawBadge
                    .padding(PPSpace.md)
            }
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
            .background(Color.homeSurface, in: cardShape)
            .overlay {
                cardShape.stroke(
                    accentColor.opacity(
                        contrast == .increased
                            ? 0.62
                            : (colorScheme == .dark ? 0.28 : 0.14)
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.8
                )
            }
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

                expandedActionCopy

                Spacer(minLength: PPSpace.xs)

                directionIndicator(size: 32)
            }
            .padding(PPSpace.md)
        } else {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    actionIcon(size: 34)

                    Spacer(minLength: PPSpace.xs)

                    compactActionCopy
                }

                directionIndicator(size: 22)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.top, PPSpace.md)
            .padding(.bottom, PPSpace.base)
        }
    }

    private var compactActionCopy: some View {
        Text(action.title)
            .font(HomeFont.bold(16))
            .foregroundStyle(Color.homeTextPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.80)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expandedActionCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Text(action.title)
                .font(HomeFont.bold(18))
                .foregroundStyle(Color.homeTextPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            if !action.subtitle.isEmpty {
                Text(action.subtitle)
                    .font(HomeFont.medium(14))
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                Color.homeSurface.opacity(
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
        static let screenGutter = PPSpace.screenMargin
        static let horizontalCellWidthScale: CGFloat = 0.85
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
                title: HomeModelAdapter.localized(
                    "home_pulse_categories_title",
                    fallback: "Explore by pet"
                ),
                subtitle: HomeModelAdapter.localized(
                    "home_pulse_categories_subtitle",
                    fallback: "The selected species shapes relevant results"
                ),
                titleAccent: Color.ppPrimary,
                actionTitle: layoutActionTitle,
                action: toggleLayout,
                actionIconName: isExpanded
                    ? "chevron.up"
                    : "chevron.forward",
                actionAccessibilityIdentifier:
                    "home.mainKinds.layoutToggle",
                actionAccessibilityValue: layoutActionTitle,
                actionGeneratesHaptic: true
            )
            .padding(.horizontal, RailLayout.screenGutter)

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
                    .padding(.horizontal, RailLayout.screenGutter)
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
        .padding(.horizontal, RailLayout.screenGutter)
        .padding(.vertical, PPSpace.xs)
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: 0, maximum: .infinity),
                spacing: RailLayout.cellSpacing,
                alignment: .top
            ),
            count: 3
        )
    }

    private var layoutActionTitle: String {
        HomeModelAdapter.localized(
            isExpanded ? "ShowLess" : "ShowAll",
            fallback: isExpanded ? "Show less" : "Show all"
        )
    }

    private var layoutTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.combined(
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
        .homeHorizontalCellReveal(
            ordinal: entranceOrdinal,
            entranceAlreadyPlayed: entrancePresented
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
        let baseSize: CGSize
        if dynamicTypeSize.isAccessibilitySize {
            baseSize = CGSize(
                width: width < 375 ? 120 : 132,
                height: 148
            )
        } else if width >= 700 {
            baseSize = CGSize(width: 140, height: 184)
        } else if width >= 430 {
            baseSize = CGSize(width: 140, height: 143)
        } else if width < 375 {
            baseSize = CGSize(width: 120, height: 130)
        } else {
            baseSize = CGSize(width: 132, height: 132)
        }
        return CGSize(
            width: baseSize.width * RailLayout.horizontalCellWidthScale,
            height: baseSize.height
        )
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

/// Continuous order journey driven only by the bridge-owned scalar progress.
/// Initial presentation is settled; real state changes retarget one private
/// rendered value and retain a static Reduce Motion equivalent.
private struct HomeOrderJourneyProgress: View {
    let progress: Double
    let accentColor: Color
    let trackColor: Color
    let beaconFillColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var displayedProgress: Double
    @State private var renderRevision = false

    private let routeHeight = PPSpace.xl + PPSpace.xs
    private let beaconDiameter = PPSpace.lg
    private let stateChangeDuration = 0.25

    init(
        progress: Double,
        accentColor: Color,
        trackColor: Color,
        beaconFillColor: Color
    ) {
        self.progress = progress
        self.accentColor = accentColor
        self.trackColor = trackColor
        self.beaconFillColor = beaconFillColor
        _displayedProgress = State(
            initialValue: min(max(progress, 0), 1)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 0)
            let routeWidth = max(totalWidth - beaconDiameter, 0)
            let progress = bounded(displayedProgress)
            let travelDistance = routeWidth * progress
            let fillWidth = min(max((beaconDiameter / 2) + travelDistance, 0), totalWidth)

            ZStack(alignment: .leading) {
                routeLayer(color: trackColor)

                routeLayer(color: accentColor)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: fillWidth, height: routeHeight)
                    }

                beaconView
                    .offset(x: (layoutDirection == .rightToLeft ? -1 : 1) * travelDistance)
            }
            .frame(width: totalWidth, height: routeHeight)
        }
        .id(renderRevision)
        .frame(height: routeHeight)
        .accessibilityHidden(true)
        .onAppear {
            displayedProgress = bounded(progress)
        }
        .onChange(of: progress) { newProgress in
            retarget(to: newProgress)
        }
        .onChange(of: reduceMotion) { enabled in
            guard enabled else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedProgress = bounded(progress)
                renderRevision.toggle()
            }
        }
    }

    private var beaconView: some View {
        ZStack {
            Circle()
                .fill(beaconFillColor)
            Circle()
                .stroke(
                    accentColor,
                    lineWidth: contrast == .increased ? 3.5 : 2.5
                )
            Circle()
                .fill(accentColor)
                .frame(
                    width: contrast == .increased
                        ? PPSpace.sm
                        : PPSpace.md / 2,
                    height: contrast == .increased
                        ? PPSpace.sm
                        : PPSpace.md / 2
                )
        }
        .frame(width: beaconDiameter, height: beaconDiameter)
    }

    private func routeLayer(color: Color) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(color)
                .frame(height: trackHeight)
                .padding(.horizontal, beaconDiameter / 2)

            HStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: endpointDiameter, height: endpointDiameter)
                Spacer(minLength: 0)
                Circle()
                    .fill(color)
                    .frame(width: endpointDiameter, height: endpointDiameter)
            }
            .padding(
                .horizontal,
                (beaconDiameter - endpointDiameter) / 2
            )
        }
        .frame(height: routeHeight)
    }

    private func retarget(to target: Double) {
        let resolvedTarget = bounded(target)
        if reduceMotion {
            displayedProgress = resolvedTarget
        } else {
            withAnimation(.easeOut(duration: stateChangeDuration)) {
                displayedProgress = resolvedTarget
            }
        }
    }

    private func bounded(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private var trackHeight: CGFloat {
        contrast == .increased ? PPSpace.md / 2 : PPSpace.xs
    }

    private var endpointDiameter: CGFloat {
        contrast == .increased ? PPSpace.sm + PPSpace.xxs : PPSpace.sm
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
                title: currentOrderTitle,
                subtitle: order.reference
            )

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityStatusHeader
                    } else {
                        compactStatusHeader
                    }

                    statusJourney
                    orderSummary
                }
                .padding(PPSpace.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    cardShape.fill(
                        LinearGradient(
                            colors: [
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
                .clipShape(cardShape)
                .contentShape(cardShape)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityOrderLabel)
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

    private var compactStatusHeader: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            statusGlyph
            statusCopy
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            disclosureIndicator
        }
    }

    private var accessibilityStatusHeader: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                statusGlyph
                Spacer(minLength: PPSpace.sm)
                disclosureIndicator
            }

            statusCopy
        }
    }

    private var statusCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(order.statusTitle)
                .font(HomeFont.bold(20))
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

    private var statusJourney: some View {
        HomeOrderJourneyProgress(
            progress: resolvedProgress,
            accentColor: statusAccent,
            trackColor: journeyTrackColor,
            beaconFillColor: statusStrongSurface
        )
        .id(order.id)
    }

    @ViewBuilder
    private var orderSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                if !order.amount.isEmpty {
                    amountLabel
                }
                itemCountLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, PPSpace.md)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(statusBorder)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
        } else {
            HStack(alignment: .center, spacing: PPSpace.md) {
                if !order.amount.isEmpty {
                    amountLabel

                    Rectangle()
                        .fill(statusBorder)
                        .frame(width: 1, height: 22)
                        .accessibilityHidden(true)
                }

                itemCountLabel
                Spacer(minLength: 0)
            }
            .padding(.top, PPSpace.md)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(statusBorder)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
        }
    }

    private var amountLabel: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusAccent)
                .accessibilityHidden(true)

            Text(order.amount)
                .font(HomeFont.bold(16))
                .foregroundStyle(Color.homeTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var itemCountLabel: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusAccent)
                .accessibilityHidden(true)

            Text(
                itemCountText
            )
            .font(HomeFont.footnote())
            .foregroundStyle(Color.homeTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusGlyph: some View {
        ZStack {
            Circle()
                .fill(statusGlyphFill)

            statusSymbol
                .foregroundStyle(statusGlyphForeground)
                .frame(width: 23, height: 23)
        }
        .frame(width: 50, height: 50)
        .overlay {
            Circle().stroke(
                statusGlyphBorder,
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
            .foregroundStyle(disclosureColor)
            .flipsForRightToLeftLayoutDirection(true)
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)
    }

    private var resolvedProgress: Double {
        min(max(order.progress, 0), 1)
    }

    private var currentOrderTitle: String {
        HomeModelAdapter.localized(
            "home_pulse_current_order_title",
            fallback: "Current order"
        )
    }

    private var itemCountText: String {
        String(
            format: HomeModelAdapter.localized(
                "home_pulse_order_items",
                fallback: "%d items"
            ),
            order.itemCount
        )
    }

    private var accessibilityOrderLabel: String {
        var components = [
            currentOrderTitle,
            order.reference,
            order.statusTitle,
            order.statusHint,
        ]
        if !order.amount.isEmpty {
            components.append(order.amount)
        }
        components.append(itemCountText)
        return components
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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

    private var statusContrastingForeground: Color {
        Color(uiColor: PPOrderStatusContrastingForegroundColor(
            statusAccentUIColor,
            statusTraits
        ))
    }

    private var statusGlyphForeground: Color {
        contrast == .increased
            ? statusContrastingForeground
            : statusAccent
    }

    private var statusGlyphFill: Color {
        contrast == .increased ? statusAccent : statusStrongSurface
    }

    private var statusGlyphBorder: Color {
        contrast == .increased
            ? statusContrastingForeground.opacity(0.72)
            : statusBorder
    }

    private var disclosureColor: Color {
        contrast == .increased ? Color.homeTextPrimary : statusAccent
    }

    private var journeyTrackColor: Color {
        contrast == .increased
            ? Color.homeTextPrimary.opacity(colorScheme == .dark ? 0.48 : 0.34)
            : statusBorder
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
                title: section.title,
                subtitle: section.subtitle,
                actionTitle: section.seeAllTitle,
                action: section.seeAllTitle == nil
                    ? nil
                    : { store.seeAll(section.kind) }
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
                                .homeHorizontalCellReveal(
                                    ordinal: ordinal,
                                    entranceAlreadyPlayed: entrancePresented
                                )
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
        .background(Color.ppSurfaceRaised)
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
                    .background(Color.ppSurfaceRaised)
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

// MARK: - HomeHorizontalCellReveal — willDisplayCell equivalent

/// World-class scroll-in animation for cells inside horizontal rails.
///
/// This is the SwiftUI equivalent of `collectionView(_:willDisplay:forItemAt:)`.
/// It fires on `.onAppear`, which is guaranteed to trigger only when a
/// `LazyHStack` cell is about to become visible — exactly the right moment.
///
/// **Dual-phase intelligence:**
/// - If `entranceAlreadyPlayed == false` the cell is being born during the
///   initial section entrance stagger; the existing `ppUniversalHomeShelfEntrance` /
///   `HomeMainKindShelfEntrance` systems own those cells. This modifier
///   immediately marks itself revealed and stays fully transparent.
/// - If `entranceAlreadyPlayed == true` the cell has lazily entered during
///   horizontal scrolling. This modifier stages it at the leading edge
///   (opacity 0, scaled down, offset toward the leading side) and then
///   springs it into its settled pose with a brief staggered delay.
///
/// **Motion design:**
///   • Scale anchor is semantic-leading so cards "grow" from where they enter
///   • Horizontal offset follows layout direction (LTR: cell enters from right → right offset; RTL: left offset)
///   • Slight upward lift (+7 pt) so the card feels like it surfaces
///   • Spring: response 0.40, damping 0.76 — snappy, alive, never bouncy enough to clash with content
///   • Stagger cap: ordinal % 3 * 0.032s — fast scroll stays fluid
///   • Reduce Motion: opacity-only crossfade, no spatial transforms
private struct HomeHorizontalCellReveal: ViewModifier {
    let ordinal: Int
    /// Pass `entrancePresented` from the parent section. When it's `true`,
    /// the one-shot entrance has completed and this modifier handles reveals.
    let entranceAlreadyPlayed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .opacity(opacityValue)
            .scaleEffect(scaleValue, anchor: semanticLeadingAnchor)
            .offset(x: offsetX, y: offsetY)
            .animation(revealAnimation, value: revealed)
            .onAppear { handleAppear() }
    }

    // MARK: Render values

    private var isStaged: Bool { !revealed && !reduceMotion }

    private var opacityValue: Double {
        guard entranceAlreadyPlayed else { return 1 }
        return revealed ? 1 : 0
    }

    private var scaleValue: CGFloat {
        guard entranceAlreadyPlayed, isStaged else { return 1 }
        return 0.95
    }

    private var offsetX: CGFloat {
        guard entranceAlreadyPlayed, isStaged else { return 0 }
        // Cards enter from the leading direction, so they start offset
        // toward the trailing edge and slide into place.
        let sign: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        return sign * 14
    }

    private var offsetY: CGFloat {
        0
    }

    private var semanticLeadingAnchor: UnitPoint {
        layoutDirection == .rightToLeft
            ? UnitPoint(x: 1, y: 0.5)
            : UnitPoint(x: 0, y: 0.5)
    }

    private var revealAnimation: Animation {
        guard entranceAlreadyPlayed else { return .easeOut(duration: 0) }
        if reduceMotion { return .easeOut(duration: 0.18) }
        let staggerDelay = Double(ordinal % 3) * 0.032
        return .spring(
            response: 0.40,
            dampingFraction: 0.76,
            blendDuration: 0.06
        )
        .delay(staggerDelay)
    }

    // MARK: onAppear

    private func handleAppear() {
        guard !revealed else { return }
        if !entranceAlreadyPlayed {
            // Initial entrance window — the section entrance modifier owns
            // this cell. Mark ourselves settled so we stay transparent.
            revealed = true
            return
        }
        // Scroll-in: fire on the next run-loop to guarantee the staged pose
        // is committed to the render tree before the spring begins.
        DispatchQueue.main.async {
            guard !revealed else { return }
            revealed = true
        }
    }
}

private extension View {
    /// Apply the scroll-in reveal animation to a horizontal rail cell.
    /// - Parameters:
    ///   - ordinal: The cell's index inside its `ForEach`. Used for stagger.
    ///   - entranceAlreadyPlayed: Pass the parent section's `entrancePresented`
    ///     flag. When `true`, this modifier handles scroll-in reveals.
    func homeHorizontalCellReveal(
        ordinal: Int,
        entranceAlreadyPlayed: Bool
    ) -> some View {
        modifier(
            HomeHorizontalCellReveal(
                ordinal: ordinal,
                entranceAlreadyPlayed: entranceAlreadyPlayed
            )
        )
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

    /// Lets soft cell elevation render outside the scroll viewport.
    ///
    /// A horizontal `ScrollView` clips to its own bounds, which cuts the
    /// elevation of cells that carry a shadow larger than the scroll content
    /// padding. Disabling the scroll clip keeps the cells' own geometry intact
    /// while allowing only their shadow to bleed.
    @ViewBuilder
    func scrollShadowClipDisabledCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
    }
}

@available(iOS 16.0, *)
struct HomePureLensSection: View {
    let motionReady: Bool
    let motionAlreadyPlayed: Bool
    let onMotionSettled: () -> Void
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isFocused: Bool
    @State private var readinessResolved = false
    @State private var didReportMotionSettled = false
    @ScaledMetric(relativeTo: .body) private var chamberHeight: CGFloat =
        HomePureLensMetrics.chamberHeight
    @ScaledMetric(relativeTo: .body) private var actionMinimumHeight: CGFloat =
        HomePureLensMetrics.actionMinimumHeight

    var body: some View {
        Button(action: performAction) {
            VStack(spacing: 0) {
                thresholdLayout
                actionRail
            }
            .frame(maxWidth: .infinity)
            .background(HomePureLensCardSurface())
            .clipShape(cardShape)
            .overlay(cardBorder)
            .contentShape(cardShape)
            .shadow(
                color: contrast == .increased || colorScheme == .dark
                    ? .clear
                    : PPShadow.card.color,
                radius: PPShadow.card.radius,
                x: PPShadow.card.x,
                y: PPShadow.card.y
            )
        }
        .buttonStyle(HomePureLensButtonStyle())
        .frame(maxWidth: HomePureLensMetrics.maximumCardWidth)
        .focused($isFocused)
        .hoverEffect(.highlight)
        .task(id: HomePureLensMotionTaskID(
            motionReady: motionReady,
            reduceMotion: reduceMotion,
            motionAlreadyPlayed: motionAlreadyPlayed,
            sceneIsActive: scenePhase == .active
        )) {
            await runReadinessResolve()
        }
        .onDisappear {
            settleReadinessWithoutAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HomeModelAdapter.localized(
            "pure_lens_account_a11y",
            fallback: "Pure Lens. Camera, recognition, and marketplace discovery."
        ))
        .accessibilityHint(HomeModelAdapter.localized(
            "pure_lens_account_hint",
            fallback: "Opens the animal discovery camera"
        ))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.pureLens.open")
    }

    @ViewBuilder
    private var thresholdLayout: some View {
        if horizontalSizeClass == .regular, !usesAccessibilityLayout {
            twoZoneThresholdLayout
        } else {
            stackedThresholdLayout
        }
    }

    private var twoZoneThresholdLayout: some View {
        HStack(alignment: .center, spacing: 0) {
            copyPanel
                .padding(PPSpace.base)
                .frame(
                    minWidth: preferredMinimumCopyWidth,
                    maxWidth: .infinity,
                    minHeight: HomePureLensMetrics.minimumTwoZoneHeight,
                    alignment: .leading
                )
                .layoutPriority(1)

            opticalChamber
                .frame(width: preferredChamberWidth)
                .frame(maxHeight: .infinity)
                .padding(.vertical, PPSpace.sm)
                .padding(.trailing, PPSpace.sm)
        }
    }

    private var stackedThresholdLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            copyPanel
                .padding(
                    usesAccessibilityLayout ? PPSpace.lg : PPSpace.base
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            opticalChamber
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PPSpace.sm)
                .padding(.bottom, PPSpace.sm)
        }
    }

    private var copyPanel: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.signal)
                    .accessibilityHidden(true)

                Text(eyebrow)
                    .font(HomeFont.bold(12))
                    .foregroundStyle(palette.eyebrowText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(title)
                .font(HomeFont.bold(27))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(outcome)
                .font(HomeFont.callout())
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var opticalChamber: some View {
        HomePureLensOpticalChamber(
            readinessResolved: presentationReady,
            minimumHeight: resolvedChamberHeight
        )
        .clipShape(chamberShape)
        .overlay {
            chamberShape
                .stroke(
                    palette.chamberContent.opacity(
                        contrast == .increased ? 0.30 : 0.12
                    ),
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
                .accessibilityHidden(true)
        }
    }

    private var actionRail: some View {
        HomePureLensActionRail(
            title: actionTitle,
            minimumHeight: actionMinimumHeight,
            readinessResolved: presentationReady
        )
        .opacity(presentationReady ? 1 : 0.78)
        .offset(y: reduceMotion || presentationReady ? 0 : 3)
    }

    private var cardBorder: some View {
        cardShape
            .strokeBorder(
                isFocused
                    ? Color.ppPrimary
                    : palette.cardBorder(
                        increasedContrast: contrast == .increased
                    ),
                lineWidth: isFocused
                    ? (contrast == .increased ? 3 : 2.4)
                    : (contrast == .increased ? 1.5 : 0.7)
            )
            .accessibilityHidden(true)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
    }

    private var chamberShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.medium,
            style: .continuous
        )
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }

    private var eyebrow: String {
        HomeModelAdapter.localized(
            "pure_lens_account_section",
            fallback: "Visual Discovery"
        )
    }

    private var title: String {
        HomeModelAdapter.localized(
            "pure_lens_account_title",
            fallback: "Pure Lens"
        )
    }

    private var outcome: String {
        HomeModelAdapter.localized(
            "home_pure_lens_subtitle",
            fallback: "Recognize an animal and discover what fits it."
        )
    }

    private var actionTitle: String {
        HomeModelAdapter.localized(
            "home_pure_lens_action",
            fallback: "Open camera"
        )
    }

    private var preferredChamberWidth: CGFloat {
        horizontalSizeClass == .regular
            ? HomePureLensMetrics.regularChamberWidth
            : HomePureLensMetrics.compactChamberWidth
    }

    private var preferredMinimumCopyWidth: CGFloat {
        horizontalSizeClass == .regular
            ? HomePureLensMetrics.regularMinimumCopyWidth
            : HomePureLensMetrics.compactMinimumCopyWidth
    }

    private var resolvedChamberHeight: CGFloat {
        min(
            max(chamberHeight, HomePureLensMetrics.chamberHeight),
            usesAccessibilityLayout
                ? HomePureLensMetrics.accessibilityMaximumChamberHeight
                : HomePureLensMetrics.maximumChamberHeight
        )
    }

    private var usesAccessibilityLayout: Bool {
        switch dynamicTypeSize {
        case .xxLarge,
             .xxxLarge,
             .accessibility1,
             .accessibility2,
             .accessibility3,
             .accessibility4,
             .accessibility5:
            return true
        default:
            return false
        }
    }

    private var presentationReady: Bool {
        reduceMotion || motionAlreadyPlayed || readinessResolved
    }

    @MainActor
    private func performAction() {
        settleReadinessWithoutAnimation()
        action()
    }

    @MainActor
    private func settleReadinessWithoutAnimation() {
        if !readinessResolved {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                readinessResolved = true
            }
        }

        reportMotionSettledIfNeeded()
    }

    @MainActor
    private func reportMotionSettledIfNeeded() {
        guard !motionAlreadyPlayed, !didReportMotionSettled else { return }
        didReportMotionSettled = true
        onMotionSettled()
    }

    @MainActor
    private func runReadinessResolve() async {
        guard motionReady else { return }

        if reduceMotion || motionAlreadyPlayed || scenePhase != .active {
            settleReadinessWithoutAnimation()
            return
        }

        guard !readinessResolved else {
            reportMotionSettledIfNeeded()
            return
        }

        withAnimation(
            .easeOut(duration: HomePureLensMetrics.readinessDuration)
        ) {
            readinessResolved = true
        }

        do {
            try await Task.sleep(
                nanoseconds: HomePureLensMetrics.readinessDurationNanoseconds
            )
        } catch {
            return
        }

        guard !Task.isCancelled, scenePhase == .active else { return }
        reportMotionSettledIfNeeded()
    }
}

private struct HomePureLensMotionTaskID: Hashable {
    let motionReady: Bool
    let reduceMotion: Bool
    let motionAlreadyPlayed: Bool
    let sceneIsActive: Bool
}

private enum HomePureLensMetrics {
    static let chamberHeight: CGFloat = 124
    static let maximumChamberHeight: CGFloat = 142
    static let accessibilityMaximumChamberHeight: CGFloat = 158
    static let compactChamberWidth: CGFloat = 132
    static let regularChamberWidth: CGFloat = 280
    static let compactMinimumCopyWidth: CGFloat = 174
    static let regularMinimumCopyWidth: CGFloat = 300
    static let minimumTwoZoneHeight: CGFloat = 160
    static let actionMinimumHeight: CGFloat = 46
    static let maximumCardWidth: CGFloat = 820
    static let readinessDuration: Double = 0.18
    static let readinessDurationNanoseconds: UInt64 = 180_000_000

    // MARK: Autofocus cycle

    /// A single autofocus pass begins soon after the card is genuinely
    /// visible. It communicates the Pure Lens capability without becoming a
    /// spinner, a progress indicator, or a permanent decorative loop.
    static let focusRestHold: UInt64 = 340_000_000
    static let focusHuntHold: UInt64 = 240_000_000
    static let focusConvergeHold: UInt64 = 200_000_000
    static let focusLockHold: UInt64 = 450_000_000
    static let focusReleaseHold: UInt64 = 240_000_000
    static let focusHuntDuration: Double = 0.24
    static let focusConvergeDuration: Double = 0.24
    static let focusLockDuration: Double = 0.22
    static let focusReleaseDuration: Double = 0.24
}

private struct HomePureLensPalette {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool

    private var isDark: Bool {
        colorScheme == .dark
    }

    var surfaceBase: Color {
        isDark ? Color.ppSurfaceElevated : Color.ppSurfaceRaised
    }

    var surfaceBrandOpacity: Double {
        isDark ? 0.16 : 0.64
    }

    var primaryText: Color {
        Color.ppTextPrimary
    }

    var secondaryText: Color {
        Color.ppTextSecondary
    }

    var eyebrowText: Color {
        Color.ppAccentText
    }

    var signal: Color {
        Color.ppPrimary
    }

    var signalPressed: Color {
        Color.ppPressedAction
    }

    var chamberBackground: Color {
        isDark ? Color.ppSurfaceElevated : Color.ppTextPrimary
    }

    var chamberContent: Color {
        isDark ? Color.ppTextPrimary : Color.ppSurfaceRaised
    }

    var actionSurface: Color {
        if reduceTransparency {
            return isDark ? Color.ppSurfaceElevated : Color.ppSurfaceRaised
        }
        return Color.ppSurfaceRaised.opacity(isDark ? 0.82 : 0.72)
    }

    var divider: Color {
        Color.ppSurfaceBorder
    }

    func cardBorder(increasedContrast: Bool) -> Color {
        if increasedContrast {
            return Color.ppTextPrimary
        }
        return Color.ppSurfaceBorder
    }
}

private struct HomePureLensButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.homePureLensIsPressed, configuration.isPressed)
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.992 : 1
            )
            .opacity(configuration.isPressed ? 0.965 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: configuration.isPressed ? 0.10 : 0.14),
                value: configuration.isPressed
            )
    }
}

private struct HomePureLensPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var homePureLensIsPressed: Bool {
        get { self[HomePureLensPressedKey.self] }
        set { self[HomePureLensPressedKey.self] = newValue }
    }
}

private struct HomePureLensCardSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            cardShape
                .fill(palette.surfaceBase)

            if !reduceTransparency {
                cardShape
                    .fill(PPGradient.softBrandField)
                    .opacity(palette.surfaceBrandOpacity)
            }
        }
        .accessibilityHidden(true)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

private struct HomePureLensActionRail: View {
    let title: String
    let minimumHeight: CGFloat
    let readinessResolved: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.homePureLensIsPressed) private var isPressed
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(isPressed ? palette.signalPressed : palette.signal)

                Circle()
                    .stroke(
                        palette.chamberContent.opacity(
                            contrast == .increased ? 0.46 : 0.24
                        ),
                        lineWidth: contrast == .increased ? 1.5 : 0.7
                    )

                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.chamberContent)
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            Text(title)
                .font(HomeFont.bold(16))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Spacer(minLength: PPSpace.sm)

            ZStack {
                Circle()
                    .fill(
                        palette.signal.opacity(isPressed ? 0.16 : 0.10)
                    )

                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.signal)
                    .offset(x: forwardOffset)
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.vertical, PPSpace.sm)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .center
        )
        .background(palette.actionSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    contrast == .increased
                        ? palette.primaryText
                        : palette.divider
                )
                .frame(height: contrast == .increased ? 1.5 : 0.7)
        }
    }

    private var forwardOffset: CGFloat {
        guard isPressed, !reduceMotion, readinessResolved else { return 0 }
        return layoutDirection == .rightToLeft ? -2 : 2
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

/// The chamber dramatizes one autofocus cycle so the entry point reads as a
/// live instrument instead of a static illustration. No camera session is
/// started here: every layer is fixed paint moved only through opacity and
/// transform, and the cycle resolves fully to rest whenever motion is
/// suppressed, the scene leaves the foreground, or the card scrolls away.
private struct HomePureLensOpticalChamber: View {
    let readinessResolved: Bool
    let minimumHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    @State private var focusPhase: HomePureLensFocusPhase = .rest
    @State private var ambientBreath = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(palette.chamberBackground)

            // Depth-of-field bloom with ambient optical breathing
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.signal.opacity(
                                reduceTransparency ? 0.38 : 0.28
                            ),
                            palette.signal.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 68
                    )
                )
                .frame(width: 136, height: 136)
                .scaleEffect(focusWashScale * (ambientBreath ? 1.06 : 0.94))
                .opacity(max(focusWashOpacity, ambientBreath ? (reduceTransparency ? 0.22 : 0.16) : 0.08))
                .allowsHitTesting(false)

            Circle()
                .strokeBorder(
                    palette.chamberContent.opacity(
                        reduceTransparency ? 0.20 : 0.12
                    ),
                    lineWidth: 1
                )
                .frame(width: 120, height: 120)
                .scaleEffect(focusFieldScale * (ambientBreath ? 1.015 : 0.985))

            Circle()
                .strokeBorder(
                    palette.signal.opacity(apertureRingOpacity),
                    lineWidth: apertureLineWidth
                )
                .frame(width: 78, height: 78)
                .scaleEffect(apertureScale * (ambientBreath ? 1.03 : 0.97))

            Circle()
                .fill(palette.chamberContent.opacity(
                    reduceTransparency ? 0.16 : 0.10
                ))
                .frame(width: 58, height: 58)
                .scaleEffect(apertureScale * (ambientBreath ? 1.02 : 0.98))

            // The subject resolves from soft to sharp on focus lock
            Image(systemName: "pawprint.fill")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(palette.chamberContent)
                .blur(radius: subjectBlurRadius)
                .scaleEffect(subjectScale * (ambientBreath ? 1.01 : 0.99))

            // Optical laser scan pass travels across the focus box during hunt
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.signal.opacity(0),
                            palette.signal.opacity(
                                reduceTransparency ? 0.88 : 0.72
                            ),
                            palette.signal.opacity(0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2.5)
                .padding(.horizontal, PPSpace.lg)
                .offset(y: scanSweepOffset)
                .opacity(scanSweepOpacity)
                .allowsHitTesting(false)

            HomePureLensFocusCorners()
                .stroke(
                    palette.chamberContent,
                    style: StrokeStyle(
                        lineWidth: contrast == .increased ? 3 : 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(PPSpace.lg)
                .opacity(focusCornerOpacity)
                .scaleEffect(focusCornerScale * (ambientBreath ? 1.012 : 0.988))

            // Autofocus confirmation indicator dot
            Circle()
                .fill(palette.signal)
                .frame(width: contrast == .increased ? 10 : 8)
                .overlay {
                    Circle()
                        .strokeBorder(
                            palette.chamberContent,
                            lineWidth: contrast == .increased ? 2 : 1
                        )
                }
                .scaleEffect(indicatorScale * (ambientBreath ? 1.08 : 0.94))
                .opacity(indicatorOpacity)
                .offset(y: -48)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            maxHeight: .infinity
        )
        .clipped()
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 2.2)
                        .repeatForever(autoreverses: true)
                ) {
                    ambientBreath = true
                }
            }
        }
        .task(id: motionLoopID) {
            await runContinuousFocusCycle()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                settleFocusWithoutAnimation()
            }
        }
        .onDisappear(perform: settleFocusWithoutAnimation)
        .accessibilityHidden(true)
    }

    // MARK: - Autofocus cycle

    /// Finite autofocus passes give the card an alive camera-specific cue.
    /// It repeats smoothly and holds at rest between optical sweeps.
    @MainActor
    private func runContinuousFocusCycle() async {
        settleFocusWithoutAnimation()
        guard !reduceMotion && scenePhase == .active else { return }

        defer { settleFocusWithoutAnimation() }

        while !Task.isCancelled && !reduceMotion && scenePhase == .active {
            // Initial rest breathing pause
            do {
                try await Task.sleep(nanoseconds: 1_200_000_000)
            } catch { return }

            guard !Task.isCancelled && !reduceMotion && scenePhase == .active else { return }

            // 1. Hunting phase: reticle expands, subject softens, scanline starts
            withAnimation(.easeInOut(duration: HomePureLensMetrics.focusHuntDuration)) {
                focusPhase = .hunting
            }
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(HomePureLensMetrics.focusHuntDuration * 1_000_000_000)
                        + HomePureLensMetrics.focusHuntHold
                )
            } catch { return }

            guard !Task.isCancelled && !reduceMotion && scenePhase == .active else { return }

            // 2. Converging phase: reticle snaps inward, scanline passes center
            withAnimation(.easeInOut(duration: HomePureLensMetrics.focusConvergeDuration)) {
                focusPhase = .converging
            }
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(HomePureLensMetrics.focusConvergeDuration * 1_000_000_000)
                        + HomePureLensMetrics.focusConvergeHold
                )
            } catch { return }

            guard !Task.isCancelled && !reduceMotion && scenePhase == .active else { return }

            // 3. Locked phase: subject snaps sharp, indicator dot pulses, green lock
            withAnimation(.spring(response: 0.26, dampingFraction: 0.65)) {
                focusPhase = .locked
            }
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(HomePureLensMetrics.focusLockDuration * 1_000_000_000)
                        + HomePureLensMetrics.focusLockHold
                )
            } catch { return }

            guard !Task.isCancelled && !reduceMotion && scenePhase == .active else { return }

            // 4. Release to ambient rest
            withAnimation(.easeOut(duration: HomePureLensMetrics.focusReleaseDuration)) {
                focusPhase = .rest
            }

            // 5. Rest interval between repeating focus cycles (3.6s)
            do {
                try await Task.sleep(nanoseconds: 3_600_000_000)
            } catch { return }
        }
    }

    @MainActor
    private func settleFocusWithoutAnimation() {
        guard focusPhase != .rest else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            focusPhase = .rest
        }
    }

    private var motionLoopID: Int {
        var hasher = Hasher()
        hasher.combine(reduceMotion)
        hasher.combine(scenePhase == .active)
        return hasher.finalize()
    }

    // MARK: - Phase-derived motion values

    private var focusCornerScale: CGFloat {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 1.055
        case .converging: return 0.972
        case .locked: return 0.992
        }
    }

    private var focusCornerOpacity: Double {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 0.62
        case .converging: return 0.9
        case .locked: return 1
        }
    }

    private var apertureScale: CGFloat {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 1.045
        case .converging: return 0.958
        case .locked: return 1
        }
    }

    private var apertureRingOpacity: Double {
        let base = reduceTransparency ? 0.72 : 0.48
        switch focusPhase {
        case .rest: return base
        case .hunting: return base * 0.72
        case .converging: return min(1, base * 1.14)
        case .locked: return min(1, base * 1.34)
        }
    }

    private var apertureLineWidth: CGFloat {
        let base: CGFloat = contrast == .increased ? 3 : 2
        return focusPhase == .locked ? base + 0.6 : base
    }

    private var subjectBlurRadius: CGFloat {
        switch focusPhase {
        case .rest: return 0
        case .hunting: return 1.9
        case .converging: return 0.7
        case .locked: return 0
        }
    }

    private var subjectScale: CGFloat {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 0.968
        case .converging: return 1.022
        case .locked: return 1
        }
    }

    private var focusFieldScale: CGFloat {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 1.018
        case .converging: return 1.006
        case .locked: return 1.012
        }
    }

    private var focusWashOpacity: Double {
        switch focusPhase {
        case .rest: return 0
        case .hunting: return 0.2
        case .converging: return 0.46
        case .locked: return 0.8
        }
    }

    private var focusWashScale: CGFloat {
        switch focusPhase {
        case .rest: return 0.92
        case .hunting: return 1.02
        case .converging: return 0.96
        case .locked: return 1.06
        }
    }

    private var scanSweepOffset: CGFloat {
        switch focusPhase {
        case .rest: return -54
        case .hunting: return -12
        case .converging: return 32
        case .locked: return 54
        }
    }

    private var scanSweepOpacity: Double {
        switch focusPhase {
        case .rest, .locked: return 0
        case .hunting: return 0.5
        case .converging: return 0.28
        }
    }

    private var indicatorScale: CGFloat {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 0.92
        case .converging: return 1
        case .locked: return 1.22
        }
    }

    private var indicatorOpacity: Double {
        switch focusPhase {
        case .rest: return 1
        case .hunting: return 0.55
        case .converging: return 0.8
        case .locked: return 1
        }
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

/// Discrete autofocus beats. Naming the beats keeps every layer's motion
/// derived from one shared state instead of independent timers.
private enum HomePureLensFocusPhase: Equatable {
    case rest
    case hunting
    case converging
    case locked
}

private struct HomePureLensFocusCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let segment = min(rect.width, rect.height) * 0.20
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + segment))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + segment, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - segment, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + segment))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - segment))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - segment, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + segment, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - segment))

        return path
    }
}

// MARK: - NextGen V6 Care-to-Listings Transition Architecture

struct HomeCareWaveTransitionShape: Shape {
    var isRightToLeft: Bool = false
    var waveDepth: CGFloat = 20.0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let baseHeight = max(0, height - waveDepth)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: baseHeight))

        if isRightToLeft {
            path.addCurve(
                to: CGPoint(x: 0, y: baseHeight),
                control1: CGPoint(x: width * 0.70, y: baseHeight + waveDepth * 1.1),
                control2: CGPoint(x: width * 0.30, y: baseHeight - waveDepth * 0.4)
            )
        } else {
            path.addCurve(
                to: CGPoint(x: 0, y: baseHeight),
                control1: CGPoint(x: width * 0.30, y: baseHeight + waveDepth * 1.1),
                control2: CGPoint(x: width * 0.70, y: baseHeight - waveDepth * 0.4)
            )
        }

        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

struct HomeCareBandOrganicTransitionBackground: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { _ in
            let isRTL = layoutDirection == .rightToLeft
            let isDark = colorScheme == .dark
            let bandColor = Color.homeSectionBand

            ZStack(alignment: .bottom) {
                // Main section band fill
                bandColor

                // Subtle ambient top entry feather
                LinearGradient(
                    colors: [
                        Color.homeCanvas.opacity(isDark ? 0.35 : 0.20),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
                .frame(maxHeight: .infinity, alignment: .top)

                // Organic Asymmetric Wave Tail
                HomeCareWaveTransitionShape(
                    isRightToLeft: isRTL,
                    waveDepth: 20
                )
                .fill(
                    LinearGradient(
                        colors: [
                            bandColor,
                            bandColor.opacity(0.85),
                            bandColor.opacity(0.40),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 36)
                .offset(y: 20)

                // Soft Dissolve Gradient blending into Canvas below
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.ppCareAccent.opacity(isDark ? 0.04 : 0.025),
                        Color.homeCanvas.opacity(isDark ? 0.65 : 0.50),
                        Color.homeCanvas
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
                .offset(y: 24)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
