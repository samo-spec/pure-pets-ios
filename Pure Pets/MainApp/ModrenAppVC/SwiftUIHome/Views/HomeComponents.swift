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

    static var controlShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
    }

    private var commandPillShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: max(
                PPCorner.medium,
                (resolvedControlHeight / 2) - (PPSpace.xs + PPSpace.xxs)
            ),
            style: .continuous
        )
    }

    private var commandTint: Color {
        Color.homeBrand.opacity(colorScheme == .dark ? 0.08 : 0.035)
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
        return min(max(commandControlHeight, 48), maximum)
    }

    private var commandVerticalSeparator: some View {
        Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: commandBorder.opacity(0), location: 0),
                        .init(color: commandBorder, location: 0.28),
                        .init(color: commandBorder, location: 0.72),
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
    private var compactCardHeight: CGFloat = 128

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
            .clipShape(cardShape)
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
        static let screenGutter = PPSpace.screenMargin
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
        if dynamicTypeSize.isAccessibilitySize {
            return CGSize(
                width: width < 375 ? 120 : 132,
                height: 148
            )
        }
        if width >= 700 {
            return CGSize(width: 140, height: 184)
        }
        if width >= 430 {
            return CGSize(width: 140, height: 143)
        }
        if width < 375 {
            return CGSize(width: 120, height: 130)
        }
        return CGSize(width: 132, height: 132)
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
        VStack(
            alignment: .leading,
            spacing: PPHomeSectionHeaderMetrics.contentSpacing
        ) {
            PPHomeSectionHeading(
                title: HomeModelAdapter.localized(
                    "home_pulse_current_order_title",
                    fallback: "Current order"
                ),
                subtitle: order.reference
            )

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
    @State private var signalPhase = HomePureLensSignalPhase.primed
    @ScaledMetric(relativeTo: .body) private var signalWindowHeight: CGFloat =
        HomePureLensMetrics.signalWindowHeight
    @ScaledMetric(relativeTo: .body) private var actionRowHeight: CGFloat =
        HomePureLensMetrics.actionHeight

    var body: some View {
        Button(action: performAction) {
            Group {
                if usesAccessibilityLayout {
                    accessibilityLayout
                } else if horizontalSizeClass == .regular {
                    regularLayout
                } else {
                    compactLayout
                }
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .focused($isFocused)
        .hoverEffect(.highlight)
        .task(id: HomePureLensMotionTaskID(
            motionReady: motionReady,
            reduceMotion: reduceMotion,
            motionAlreadyPlayed: motionAlreadyPlayed
        )) {
            await runSignalStory()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase != .active {
                settleSignalWithoutAnimation()
            }
        }
        .onDisappear {
            settleSignalWithoutAnimation()
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

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            copyPanel
            signalWindow(height: resolvedSignalWindowHeight)
            actionPanel
        }
    }

    private var regularLayout: some View {
        HStack(alignment: .center, spacing: PPSpace.xl) {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                copyPanel
                actionPanel
            }
            .frame(
                maxWidth: HomePureLensMetrics.maximumRegularCopyWidth,
                alignment: .leading
            )
            .layoutPriority(1)

            signalWindow(height: HomePureLensMetrics.regularSignalWindowHeight)
                .frame(maxWidth: HomePureLensMetrics.maximumRegularSignalWidth)
        }
        .frame(maxWidth: HomePureLensMetrics.maximumRegularContentWidth)
        .frame(maxWidth: .infinity)
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            copyPanel
            signalWindow(height: resolvedSignalWindowHeight)
            actionPanel
        }
    }

    private var copyPanel: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            brandLockup

            Text(outcome)
                .font(HomeFont.callout())
                .foregroundStyle(palette.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(presentationPhase.reachedContext ? 1 : 0.74)
                .offset(
                    y: reduceMotion || presentationPhase.reachedContext
                        ? 0
                        : 5
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionPanel: some View {
        actionLabel
            .opacity(presentationPhase.reachedDiscovery ? 1 : 0.76)
            .offset(
                y: reduceMotion || presentationPhase.reachedDiscovery
                    ? 0
                    : 4
            )
    }

    private var brandLockup: some View {
        VStack(alignment: .leading, spacing: PPSpace.xxs) {
            Group {
                if usesAccessibilityLayout {
                    VStack(alignment: .leading, spacing: PPSpace.xs) {
                        eyebrowLabel
                        aiBadge
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                        eyebrowLabel

                        Spacer(minLength: PPSpace.sm)

                        aiBadge
                    }
                }
            }
            .opacity(presentationPhase.reachedIdentity ? 1 : 0.78)
            .offset(
                y: reduceMotion || presentationPhase.reachedIdentity
                    ? 0
                    : 4
            )

            Text(title)
                .font(HomeFont.bold(26))
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(presentationPhase.reachedIdentity ? 1 : 0.82)
                .offset(
                    y: reduceMotion || presentationPhase.reachedIdentity
                        ? 0
                        : 4
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var aiBadge: some View {
        HomePureLensAIBadge()
            .scaleEffect(
                reduceMotion || presentationPhase.reachedIdentity ? 1 : 0.94
            )
    }

    private var eyebrowLabel: some View {
        Text(eyebrow)
            .font(HomeFont.bold(12))
            .foregroundStyle(palette.eyebrowText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionLabel: some View {
        HomePureLensActionLabel(
            title: actionTitle,
            minimumHeight: resolvedActionRowHeight,
            allowsMultiline: usesAccessibilityLayout,
            phase: presentationPhase
        )
    }

    private func signalWindow(height: CGFloat) -> some View {
        HomePureLensSignalWindow(
            phase: presentationPhase,
            height: height
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .opacity(presentationPhase.reachedContext ? 1 : 0.88)
        .scaleEffect(
            reduceMotion || presentationPhase.reachedContext ? 1 : 0.99
        )
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
            .opacity(presentationPhase.reachedIdentity ? 1 : 0.82)
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

    private var contentPadding: CGFloat {
        usesAccessibilityLayout ? PPSpace.lg : PPSpace.base
    }

    private var resolvedSignalWindowHeight: CGFloat {
        min(
            signalWindowHeight,
            usesAccessibilityLayout
                ? HomePureLensMetrics.maximumAccessibilitySignalWindowHeight
                : HomePureLensMetrics.maximumStandardSignalWindowHeight
        )
    }

    private var resolvedActionRowHeight: CGFloat {
        min(
            actionRowHeight,
            usesAccessibilityLayout
                ? HomePureLensMetrics.maximumAccessibilityActionHeight
                : HomePureLensMetrics.maximumStandardActionHeight
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

    private var presentationPhase: HomePureLensSignalPhase {
        reduceMotion || motionAlreadyPlayed
            ? .discoveryReady
            : signalPhase
    }

    @MainActor
    private func performAction() {
        settleSignalWithoutAnimation()
        action()
    }

    @MainActor
    private func settleSignalWithoutAnimation() {
        if signalPhase != .discoveryReady {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                signalPhase = .discoveryReady
            }
        }

        if !motionAlreadyPlayed {
            onMotionSettled()
        }
    }

    @MainActor
    private func runSignalStory() async {
        guard motionReady else { return }

        if reduceMotion || motionAlreadyPlayed {
            settleSignalWithoutAnimation()
            return
        }

        if scenePhase != .active {
            settleSignalWithoutAnimation()
            return
        }

        guard signalPhase == .primed else { return }

        guard
            signalPhase == .primed,
            motionReady
        else { return }
        withAnimation(
            .easeOut(duration: HomePureLensMetrics.identityDuration)
        ) {
            signalPhase = .identityReady
        }

        guard await waitForMotionDelay(
            HomePureLensMetrics.contextStaggerNanoseconds
        ) else { return }

        guard
            signalPhase == .identityReady,
            motionReady
        else { return }
        withAnimation(
            .easeOut(duration: HomePureLensMetrics.contextDuration)
        ) {
            signalPhase = .contextReady
        }

        guard await waitForMotionDelay(
            HomePureLensMetrics.acquisitionStaggerNanoseconds
        ) else { return }

        guard
            signalPhase == .contextReady,
            motionReady
        else { return }
        withAnimation(
            .easeOut(duration: HomePureLensMetrics.recognitionDuration)
        ) {
            signalPhase = .animalAcquired
        }

        guard await waitForMotionDelay(
            HomePureLensMetrics.discoveryDwellNanoseconds
        ) else { return }

        guard
            signalPhase == .animalAcquired,
            motionReady
        else { return }
        withAnimation(
            .spring(
                response: HomePureLensMetrics.discoveryResponse,
                dampingFraction: HomePureLensMetrics.discoveryDamping,
                blendDuration: 0.02
            )
        ) {
            signalPhase = .discoveryReady
        }
        onMotionSettled()
    }

    @MainActor
    private func waitForMotionDelay(_ nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return false
        }

        return !Task.isCancelled && scenePhase == .active
    }
}

private enum HomePureLensSignalPhase: Equatable {
    case primed
    case identityReady
    case contextReady
    case animalAcquired
    case discoveryReady

    var reachedIdentity: Bool {
        self != .primed
    }

    var reachedContext: Bool {
        switch self {
        case .primed, .identityReady:
            return false
        case .contextReady, .animalAcquired, .discoveryReady:
            return true
        }
    }

    var reachedRecognition: Bool {
        self == .animalAcquired || self == .discoveryReady
    }

    var reachedDiscovery: Bool {
        self == .discoveryReady
    }
}

private struct HomePureLensMotionTaskID: Hashable {
    let motionReady: Bool
    let reduceMotion: Bool
    let motionAlreadyPlayed: Bool
}

private enum HomePureLensMetrics {
    static let signalWindowHeight: CGFloat = 128
    static let maximumStandardSignalWindowHeight: CGFloat = 144
    static let maximumAccessibilitySignalWindowHeight: CGFloat = 176
    static let regularSignalWindowHeight: CGFloat = 160
    static let maximumRegularSignalWidth: CGFloat = 340
    static let maximumRegularCopyWidth: CGFloat = 356
    static let maximumRegularContentWidth: CGFloat = 760
    static let actionHeight: CGFloat = 50
    static let maximumStandardActionHeight: CGFloat = 58
    static let maximumAccessibilityActionHeight: CGFloat = 76
    static let contextStaggerNanoseconds: UInt64 = 60_000_000
    static let acquisitionStaggerNanoseconds: UInt64 = 80_000_000
    static let discoveryDwellNanoseconds: UInt64 = 250_000_000
    static let identityDuration: Double = 0.16
    static let contextDuration: Double = 0.18
    static let recognitionDuration: Double = 0.22
    static let discoveryResponse: Double = 0.28
    static let discoveryDamping: Double = 0.88
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

    var primaryText: Color {
        Color.ppTextPrimary
    }

    var secondaryText: Color {
        Color.ppTextSecondary
    }

    var eyebrowText: Color {
        Color.ppAccentText
    }

    var signalBackground: Color {
        isDark ? Color.black : Color.ppTextPrimary
    }

    var signalBorder: Color {
        Color.white.opacity(reduceTransparency ? 0.58 : 0.24)
    }

    var signalActive: Color {
        Color.ppPrimary
    }

    var signalSubjectFill: Color {
        Color.ppPrimaryDarker
    }

    var signalSubject: Color {
        Color.white.opacity(reduceTransparency ? 0.96 : 0.92)
    }

    var signalContent: Color {
        Color.white.opacity(reduceTransparency ? 1 : 0.94)
    }

    var badgeFill: Color {
        Color.ppPrimary.opacity(isDark ? 0.20 : 0.10)
    }

    var badgeBorder: Color {
        Color.ppPrimary.opacity(isDark ? 0.46 : 0.20)
    }

    func cardBorder(increasedContrast: Bool) -> Color {
        if isDark {
            return Color.white.opacity(increasedContrast ? 0.82 : 0.20)
        }
        return increasedContrast ? Color.ppTextPrimary : Color.ppSurfaceBorder
    }

    func ctaFill(isPressed: Bool) -> Color {
        isPressed ? Color.ppPrimaryDarker : Color.ppPrimary
    }

    var ctaContent: Color {
        Color.white
    }
}

private struct HomePureLensAIBadge: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.xxs) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))

            Text(HomeModelAdapter.localized("AI", fallback: "AI"))
                .font(HomeFont.bold(11))
        }
        .foregroundStyle(Color.ppAccentText)
        .padding(.horizontal, PPSpace.sm)
        .frame(minHeight: 28)
        .background(
            palette.badgeFill,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    contrast == .increased
                        ? Color.ppPrimary
                        : palette.badgeBorder,
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
        }
        .accessibilityHidden(true)
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

private struct HomePureLensActionLabel: View {
    let title: String
    let minimumHeight: CGFloat
    let allowsMultiline: Bool
    let phase: HomePureLensSignalPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.homePureLensIsPressed) private var isPressed
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.ctaContent)
                .scaleEffect(
                    reduceMotion || phase.reachedDiscovery ? 1 : 0.92
                )
                .accessibilityHidden(true)

            Text(title)
                .font(HomeFont.bold(16))
                .foregroundStyle(palette.ctaContent)
                .lineLimit(allowsMultiline ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: PPSpace.sm)

            Image(systemName: directionalArrowSymbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.ctaContent)
                .offset(x: forwardOffset)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PPSpace.base)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .center
        )
        .background(
            palette.ctaFill(isPressed: isPressed),
            in: RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            if contrast == .increased {
                RoundedRectangle(
                    cornerRadius: PPCorner.medium,
                    style: .continuous
                )
                .strokeBorder(palette.ctaContent, lineWidth: 1.5)
            }
        }
    }

    private var forwardOffset: CGFloat {
        guard isPressed, !reduceMotion else { return 0 }
        return layoutDirection == .rightToLeft ? -2 : 2
    }

    private var directionalArrowSymbol: String {
        layoutDirection == .rightToLeft ? "arrow.left" : "arrow.right"
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
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

private struct HomePureLensButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.homePureLensIsPressed, configuration.isPressed)
            .scaleEffect(
                configuration.isPressed && !reduceMotion ? 0.988 : 1
            )
            .opacity(configuration.isPressed ? 0.965 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : (configuration.isPressed
                        ? .easeOut(duration: 0.14)
                        : .easeOut(duration: 0.10)),
                value: configuration.isPressed
            )
    }
}

private struct HomePureLensCardSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )
        .fill(palette.surfaceBase)
        .accessibilityHidden(true)
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

private struct HomePureLensSignalWindow: View {
    let phase: HomePureLensSignalPhase
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .fill(palette.signalBackground)

            HomePureLensViewfinderGrid()
                .stroke(
                    palette.signalContent.opacity(
                        reduceTransparency ? 0.18 : 0.10
                    ),
                    lineWidth: 0.7
                )
                .padding(.horizontal, PPSpace.lg)
                .padding(.vertical, PPSpace.base)
                .opacity(focusOpacity)
                .accessibilityHidden(true)

            HomePureLensFocusCorners()
                .stroke(
                    palette.signalContent,
                    style: StrokeStyle(
                        lineWidth: contrast == .increased ? 3 : 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(.horizontal, PPSpace.lg)
                .padding(.vertical, PPSpace.base)
                .scaleEffect(focusScale)
                .opacity(focusOpacity)

            ZStack {
                Circle()
                    .strokeBorder(
                        palette.signalActive,
                        lineWidth: contrast == .increased ? 3 : 2
                    )
                    .frame(
                        width: recognitionRingDiameter,
                        height: recognitionRingDiameter
                    )
                    .scaleEffect(recognitionRingScale)
                    .opacity(recognitionRingOpacity)

                Circle()
                    .fill(palette.signalSubjectFill)
                    .frame(width: subjectDiameter, height: subjectDiameter)

                Image(systemName: "pawprint.fill")
                    .font(.system(
                        size: subjectDiameter * 0.42,
                        weight: .bold
                    ))
                    .foregroundStyle(palette.signalSubject)
            }
            .scaleEffect(subjectScale)
            .opacity(subjectOpacity)
            .offset(y: -PPSpace.lg)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HomePureLensResultChip(phase: phase)
                    .padding(.bottom, PPSpace.sm)
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PPCorner.medium,
                style: .continuous
            )
            .strokeBorder(
                palette.signalBorder,
                lineWidth: contrast == .increased ? 2 : 1
            )
        }
        .accessibilityHidden(true)
    }

    private var subjectDiameter: CGFloat {
        min(58, max(46, height * 0.36))
    }

    private var recognitionRingDiameter: CGFloat {
        subjectDiameter + PPSpace.md * 2
    }

    private var recognitionRingScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return phase.reachedRecognition ? 1 : 1.18
    }

    private var recognitionRingOpacity: Double {
        phase.reachedRecognition ? 1 : 0
    }

    private var focusScale: CGFloat {
        guard !reduceMotion else { return 1 }
        switch phase {
        case .primed, .identityReady, .contextReady:
            return 1.03
        case .animalAcquired:
            return 0.99
        case .discoveryReady:
            return 1
        }
    }

    private var subjectScale: CGFloat {
        let phaseScale: CGFloat
        if reduceMotion {
            phaseScale = 1
        } else {
            switch phase {
            case .primed, .identityReady, .contextReady:
                phaseScale = 0.95
            case .animalAcquired:
                phaseScale = 1.02
            case .discoveryReady:
                phaseScale = 1
            }
        }
        return phaseScale
    }

    private var subjectOpacity: Double {
        guard !reduceMotion else { return 1 }
        switch phase {
        case .primed, .identityReady, .contextReady:
            return 0.72
        case .animalAcquired:
            return 1
        case .discoveryReady:
            return 1
        }
    }

    private var focusOpacity: Double {
        guard !reduceMotion else { return 1 }
        return phase.reachedRecognition ? 1 : 0.74
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
}

private struct HomePureLensResultChip: View {
    let phase: HomePureLensSignalPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))

            Text(label)
                .font(HomeFont.bold(12))
                .lineLimit(1)
        }
        .foregroundStyle(palette.signalContent)
        .padding(.horizontal, PPSpace.md)
        .frame(height: 34)
        .background(chipFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    contrast == .increased
                        ? palette.signalContent
                        : palette.signalBorder,
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
        }
        .scaleEffect(reduceMotion || phase.reachedRecognition ? 1 : 0.9)
        .opacity(phase.reachedRecognition ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var isDiscovery: Bool {
        phase.reachedDiscovery
    }

    private var symbol: String {
        isDiscovery ? "sparkles" : "viewfinder"
    }

    private var label: String {
        isDiscovery
            ? HomeModelAdapter.localized(
                "pure_lens_account_discover",
                fallback: "Discover"
            )
            : HomeModelAdapter.localized(
                "pure_lens_account_recognize",
                fallback: "Recognize"
            )
    }

    private var chipFill: Color {
        isDiscovery
            ? palette.signalActive
            : Color.black.opacity(reduceTransparency ? 0.58 : 0.34)
    }

    private var palette: HomePureLensPalette {
        HomePureLensPalette(
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        )
    }
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

private struct HomePureLensViewfinderGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columnWidth = rect.width / 3
        let rowHeight = rect.height / 3

        for index in 1...2 {
            let x = rect.minX + columnWidth * CGFloat(index)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for index in 1...2 {
            let y = rect.minY + rowHeight * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}
