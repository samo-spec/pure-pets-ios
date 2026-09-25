//
//  AdoptPetListScreen.swift
//  Pure Pets
//
//  Category-defining Adoption Pet Discovery Experience.
//  First-Principles Redesign: Dedicated iPhone and iPad architectures,
//  exclusive Beiruti brand typography, 6-state resilience, and ADA-caliber craft.
//

import SwiftUI
import UIKit

// MARK: - Exclusive Typography Engine (100% Beiruti Only)

private enum AdoptFont {
    static func bold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: style)
    }

    static func medium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: style)
    }

    static func regular(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Tactile Haptics

private enum AdoptHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impactLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func impactMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Press Style

private struct AdoptPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed || !isEnabled ? 1 : pressedScale)
            .opacity(!isEnabled ? 0.46 : (configuration.isPressed ? 0.88 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Main Root Container (Device Adaptive Routing)

struct AdoptPetListScreen: View {
    @StateObject private var store = AdoptPetListStore()

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var onSelectPet: (AdoptPetModel) -> Void
    var onAddPet: () -> Void
    var onClose: (() -> Void)? = nil

    @State private var hasAppeared = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var shouldUsePadArchitecture: Bool {
        isPad && horizontalSizeClass != .compact
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = resolvedTopInset(proxy)
            ZStack {
                Color.ppBackground
                    .ignoresSafeArea()

                Group {
                    if shouldUsePadArchitecture {
                        AdoptPetList_iPad(
                            store: store,
                            topInset: topInset,
                            onSelectPet: onSelectPet,
                            onAddPet: onAddPet,
                            onClose: onClose
                        )
                    } else {
                        AdoptPetList_iPhone(
                            store: store,
                            topInset: topInset,
                            onSelectPet: onSelectPet,
                            onAddPet: onAddPet,
                            onClose: onClose
                        )
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            store.startObserving()
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    hasAppeared = true
                }
            }
        }
        .onDisappear {
            store.stopObserving()
        }
    }

    private func resolvedTopInset(_ proxy: GeometryProxy) -> CGFloat {
        let inset = proxy.safeAreaInsets.top
        if inset > 1 {
            return inset
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 44
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - iPhone Dedicated Architecture
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetList_iPhone: View {
    @ObservedObject var store: AdoptPetListStore
    let topInset: CGFloat
    var onSelectPet: (AdoptPetModel) -> Void
    var onAddPet: () -> Void
    var onClose: (() -> Void)?

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @FocusState private var searchIsFocused: Bool
    @State private var pulseHeart = false

    var body: some View {
        VStack(spacing: 0) {
            navigationHeader
                .zIndex(2)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: PPSpace.lg) {
                    editorialHeroDeck

                    discoveryCockpit

                    if store.hasStaleConnectionIssue || (store.isRefreshing && !store.pets.isEmpty) {
                        cachedConnectionBanner
                    }

                    activeStateContent
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.top, PPSpace.md)
                .padding(.bottom, PPSpace.xxxxl)
            }
            .refreshable {
                await store.refresh()
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - iPhone Navigation Bar

    private var navigationHeader: some View {
        HStack(spacing: PPSpace.sm) {
            if let onClose {
                Button(action: {
                    AdoptHaptics.impactLight()
                    onClose()
                }) {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 42, height: 42)
                        .background(Color.ppSurface, in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    colorSchemeContrast == .increased
                                        ? Color.ppTextPrimary.opacity(0.6)
                                        : Color.ppBorder.opacity(0.72),
                                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                                )
                        }
                }
                .buttonStyle(AdoptPressStyle())
                .accessibilityLabel(PPAdoptLang("Back"))
            }

            // Center Brand Badge
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .scaleEffect(pulseHeart && !reduceMotion ? 1.15 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulseHeart
                    )
                    .frame(width: 28, height: 28)
                    .background(Color.ppQuickActionAdoption.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                Text(PPAdoptLang("adopt_list_eyebrow"))
                    .font(AdoptFont.bold(16, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, 6)
            .background(Color.ppSurface.opacity(0.9), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.ppQuickActionAdoption.opacity(0.25), lineWidth: 0.8)
            }
            .onAppear {
                if !reduceMotion {
                    pulseHeart = true
                }
            }

            Spacer(minLength: PPSpace.xs)

            // Primary Add Action
            Button(action: {
                AdoptHaptics.impactMedium()
                onAddPet()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))

                    Text(PPAdoptLang("adopt_list_add_action"))
                        .font(AdoptFont.bold(14, relativeTo: .subheadline))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.md)
                .frame(height: 40)
                .background(
                    LinearGradient(
                        colors: [
                            Color.ppQuickActionAdoption,
                            Color.ppQuickActionAdoption.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(
                    color: Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.35 : 0.25),
                    radius: 8,
                    y: 3
                )
            }
            .buttonStyle(AdoptPressStyle())
            .accessibilityLabel(PPAdoptLang("adopt_list_add_action"))
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, topInset + PPSpace.xs)
        .padding(.bottom, PPSpace.sm)
        .background(
            Color.ppElevatedSurface
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, y: 3)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.6))
                .frame(height: colorSchemeContrast == .increased ? 1 : 0.5)
        }
    }

    // MARK: - iPhone Warm Editorial Hero Deck

    private var editorialHeroDeck: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)

                let availableCount = store.pets.filter { $0.visibility == 0 }.count
                Text(String(format: PPAdoptLang("adopt_list_count_format"), availableCount))
                    .font(AdoptFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppQuickActionAdoption)

                Spacer()
            }
            .padding(.horizontal, PPSpace.sm)
            .padding(.vertical, 4)
            .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())
            .fixedSize()

            Text(PPAdoptLang("adopt_list_title"))
                .font(AdoptFont.bold(28, relativeTo: .title))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(0.84)
                .accessibilityAddTraits(.isHeader)

            Text(PPAdoptLang("adopt_list_subtitle"))
                .font(AdoptFont.regular(14, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.18 : 0.10),
                            Color.ppSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    Color.ppQuickActionAdoption.opacity(colorSchemeContrast == .increased ? 0.8 : 0.22),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
    }

    // MARK: - iPhone Discovery Cockpit

    private var discoveryCockpit: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            AdoptSearchField(
                searchText: $store.searchText,
                isFocused: $searchIsFocused
            )

            speciesSelectorBar

            genderSelectorBar

            if store.hasActiveFilters {
                activeFiltersBanner
            }
        }
    }

    private var speciesSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.xs) {
                // All Chip
                speciesChip(
                    title: PPAdoptLang("All"),
                    symbol: "square.grid.2x2.fill",
                    count: store.pets.filter { $0.visibility == 0 }.count,
                    isSelected: store.selectedKindID == 0
                ) {
                    store.selectedKindID = 0
                }

                // Dynamic Kinds from MainKindsArrayManager
                if let kinds = MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel] {
                    ForEach(kinds, id: \.id) { kind in
                        let name = kind.kindName
                        if !name.isEmpty {
                            let count = store.pets.filter { $0.visibility == 0 && $0.kindID == kind.id }.count
                            speciesChip(
                                title: name,
                                symbol: symbolForKind(name: name),
                                count: count,
                                isSelected: store.selectedKindID == kind.id
                            ) {
                                store.selectedKindID = store.selectedKindID == kind.id ? 0 : kind.id
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func speciesChip(
        title: String,
        symbol: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            AdoptHaptics.selection()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.ppQuickActionAdoption)

                Text(title)
                    .font(AdoptFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)

                if count > 0 {
                    Text("\(count)")
                        .font(AdoptFont.bold(11, relativeTo: .caption2))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.ppTextSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            (isSelected ? Color.black.opacity(0.18) : Color.ppSecondarySurface),
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, PPSpace.md)
            .frame(height: 38)
            .background(
                isSelected
                    ? Color.ppQuickActionAdoption
                    : Color.ppSurface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.ppQuickActionAdoption
                            : Color.ppBorder.opacity(0.7),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            }
            .shadow(
                color: isSelected ? Color.ppQuickActionAdoption.opacity(0.22) : Color.clear,
                radius: 4,
                y: 2
            )
        }
        .buttonStyle(AdoptPressStyle(pressedScale: 0.96))
        .accessibilityLabel("\(title), \(count)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var genderSelectorBar: some View {
        HStack(spacing: PPSpace.xs) {
            genderChip(
                title: PPAdoptLang("All"),
                symbol: "pawprint.fill",
                isSelected: store.selectedGender.isEmpty
            ) {
                store.selectedGender = ""
            }

            genderChip(
                title: PPAdoptLang("Male"),
                symbol: "figure.stand",
                isSelected: store.selectedGender == "male"
            ) {
                store.selectedGender = store.selectedGender == "male" ? "" : "male"
            }

            genderChip(
                title: PPAdoptLang("Female"),
                symbol: "person.fill",
                isSelected: store.selectedGender == "female"
            ) {
                store.selectedGender = store.selectedGender == "female" ? "" : "female"
            }

            Spacer(minLength: 0)
        }
    }

    private func genderChip(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            AdoptHaptics.selection()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))

                Text(title)
                    .font(AdoptFont.medium(12, relativeTo: .caption))
            }
            .foregroundStyle(isSelected ? Color.ppQuickActionAdoption : Color.ppTextSecondary)
            .padding(.horizontal, PPSpace.sm)
            .frame(height: 32)
            .background(
                isSelected
                    ? Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.24 : 0.14)
                    : Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.ppQuickActionAdoption
                            : Color.ppBorder.opacity(0.6),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            }
        }
        .buttonStyle(AdoptPressStyle(pressedScale: 0.96))
    }

    private var activeFiltersBanner: some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ppQuickActionAdoption)

            Text(String(format: PPAdoptLang("adopt_list_filtered_count_format"), store.filteredPets.count))
                .font(AdoptFont.bold(12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextPrimary)

            Spacer()

            Button(action: {
                AdoptHaptics.impactLight()
                store.clearFilters()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                    Text(PPAdoptLang("ClearFilters"))
                        .font(AdoptFont.bold(12, relativeTo: .caption))
                }
                .foregroundStyle(Color.ppQuickActionAdoption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())
            }
            .buttonStyle(AdoptPressStyle())
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, 8)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .strokeBorder(Color.ppQuickActionAdoption.opacity(0.3), lineWidth: 0.8)
        }
    }

    // MARK: - iPhone Content States

    @ViewBuilder
    private var activeStateContent: some View {
        if store.isLoading && store.pets.isEmpty {
            AdoptPetSkeletonView(isPad: false)
        } else if store.isOffline && store.pets.isEmpty {
            AdoptPetStatePanel(
                symbol: "wifi.slash",
                tint: .ppWarning,
                title: PPAdoptLang("adopt_list_error_title"),
                message: PPAdoptLang("adopt_list_error_subtitle"),
                primaryTitle: PPAdoptLang("Retry"),
                primarySymbol: "arrow.clockwise",
                primaryAction: { store.requestRefresh() }
            )
        } else if let error = store.errorMessage, store.pets.isEmpty, !store.isOffline {
            AdoptPetStatePanel(
                symbol: "exclamationmark.triangle.fill",
                tint: .ppError,
                title: PPAdoptLang("adopt_list_error_title"),
                message: error,
                primaryTitle: PPAdoptLang("Retry"),
                primarySymbol: "arrow.clockwise",
                primaryAction: { store.requestRefresh() }
            )
        } else if store.pets.isEmpty {
            // Platform Zero State
            AdoptPetStatePanel(
                symbol: "heart.circle.fill",
                tint: .ppQuickActionAdoption,
                title: PPAdoptLang("adopt_list_empty_title"),
                message: PPAdoptLang("adopt_list_empty_subtitle"),
                primaryTitle: PPAdoptLang("adopt_list_add_action"),
                primarySymbol: "plus",
                primaryAction: onAddPet
            )
        } else if store.filteredPets.isEmpty {
            // Filtered Zero State
            AdoptPetStatePanel(
                symbol: "magnifyingglass",
                tint: .ppQuickActionAdoption,
                title: PPAdoptLang("adopt_list_no_results_title"),
                message: PPAdoptLang("adopt_list_no_results_subtitle"),
                primaryTitle: PPAdoptLang("ClearFilters"),
                primarySymbol: "arrow.counterclockwise",
                primaryAction: { store.clearFilters() }
            )
        } else {
            populatedContent
        }
    }

    private var populatedContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            // Curated Lead Hero Pet
            if let leadPet = store.filteredPets.first {
                Button(action: {
                    AdoptHaptics.impactLight()
                    onSelectPet(leadPet)
                }) {
                    AdoptPetLeadCard(
                        pet: leadPet,
                        usesSplitLayout: false
                    )
                }
                .buttonStyle(AdoptPressStyle(pressedScale: 0.985))
                .accessibilityLabel(cardAccessibilityLabel(for: leadPet))
                .onAppear { store.loadNextIfNeeded(current: leadPet) }
            }

            // Companions Feed
            if store.filteredPets.count > 1 {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                    Text(PPAdoptLang("adopt_list_results_title"))
                        .font(AdoptFont.bold(18, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)

                    Spacer()

                    Text(String(format: PPAdoptLang("adopt_list_count_format"), store.filteredPets.count - 1))
                        .font(AdoptFont.medium(12, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                }
                .padding(.top, PPSpace.sm)

                LazyVStack(spacing: PPSpace.md) {
                    ForEach(store.filteredPets.dropFirst(), id: \.documentID) { pet in
                        Button(action: {
                            AdoptHaptics.impactLight()
                            onSelectPet(pet)
                        }) {
                            AdoptPetCompanionCard(
                                pet: pet,
                                isCompact: true
                            )
                        }
                        .buttonStyle(AdoptPressStyle(pressedScale: 0.985))
                        .accessibilityLabel(cardAccessibilityLabel(for: pet))
                        .onAppear { store.loadNextIfNeeded(current: pet) }
                    }
                }
            }
        }
    }

    private var cachedConnectionBanner: some View {
        AdoptCachedBanner(store: store)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - iPad Dedicated Architecture (Adaptive 2-Pane Studio)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetList_iPad: View {
    @ObservedObject var store: AdoptPetListStore
    let topInset: CGFloat
    var onSelectPet: (AdoptPetModel) -> Void
    var onAddPet: () -> Void
    var onClose: (() -> Void)?

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @FocusState private var searchIsFocused: Bool
    @State private var pulseHeart = false

    var body: some View {
        VStack(spacing: 0) {
            ipadTopBar
                .zIndex(3)

            HStack(alignment: .top, spacing: 0) {
                // Leading Cockpit & Intelligence Sidebar (~360pt)
                AdoptPetCockpitSidebar(
                    store: store,
                    searchIsFocused: $searchIsFocused,
                    onAddPet: onAddPet
                )
                .frame(width: 360)
                .background(Color.ppSecondarySurface)
                .overlay(alignment: layoutDirection == .rightToLeft ? .leading : .trailing) {
                    Rectangle()
                        .fill(Color.ppSeparator.opacity(0.6))
                        .frame(width: 0.8)
                }

                // Trailing Gallery & Companion Canvas
                AdoptPetCanvasGallery(
                    store: store,
                    onSelectPet: onSelectPet,
                    onAddPet: onAddPet
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .top)
        .keyboardShortcut("f", modifiers: .command)
    }

    // MARK: - iPad Top Studio Bar

    private var ipadTopBar: some View {
        HStack(spacing: PPSpace.md) {
            if let onClose {
                Button(action: {
                    AdoptHaptics.impactLight()
                    onClose()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text(PPAdoptLang("Back"))
                            .font(AdoptFont.bold(14, relativeTo: .subheadline))
                    }
                    .foregroundStyle(Color.ppTextPrimary)
                    .padding(.horizontal, PPSpace.md)
                    .frame(height: 40)
                    .background(Color.ppSurface, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                    }
                }
                .buttonStyle(AdoptPressStyle())
                .keyboardShortcut(.cancelAction)
            }

            // Brand Heart Badge
            HStack(spacing: PPSpace.xs) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .scaleEffect(pulseHeart && !reduceMotion ? 1.15 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulseHeart
                    )
                    .frame(width: 30, height: 30)
                    .background(Color.ppQuickActionAdoption.opacity(0.14), in: Circle())

                Text(PPAdoptLang("adopt_list_eyebrow"))
                    .font(AdoptFont.bold(18, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, 6)
            .background(Color.ppSurface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.ppQuickActionAdoption.opacity(0.24), lineWidth: 0.8)
            }
            .onAppear {
                if !reduceMotion {
                    pulseHeart = true
                }
            }

            Spacer()

            // Header Quick Stats
            HStack(spacing: PPSpace.sm) {
                let count = store.pets.filter { $0.visibility == 0 }.count
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(String(format: PPAdoptLang("adopt_list_count_format"), count))
                        .font(AdoptFont.bold(13, relativeTo: .caption))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                }
                .padding(.horizontal, PPSpace.sm)
                .padding(.vertical, 6)
                .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())

                // Prominent iPad Add Button
                Button(action: {
                    AdoptHaptics.impactMedium()
                    onAddPet()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))

                        Text(PPAdoptLang("adopt_list_add_action"))
                            .font(AdoptFont.bold(14, relativeTo: .subheadline))

                        Text("⌘N")
                            .font(AdoptFont.regular(10, relativeTo: .caption2))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, PPSpace.lg)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.ppQuickActionAdoption,
                                Color.ppQuickActionAdoption.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(
                        color: Color.ppQuickActionAdoption.opacity(0.28),
                        radius: 8,
                        y: 3
                    )
                }
                .buttonStyle(AdoptPressStyle())
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .padding(.horizontal, PPSpace.xl)
        .padding(.top, topInset + PPSpace.xs)
        .padding(.bottom, PPSpace.sm)
        .background(Color.ppElevatedSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.6))
                .frame(height: 0.8)
        }
    }
}

// MARK: - iPad Sidebar Cockpit

private struct AdoptPetCockpitSidebar: View {
    @ObservedObject var store: AdoptPetListStore
    var searchIsFocused: FocusState<Bool>.Binding
    var onAddPet: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PPSpace.xl) {
                // Sidebar Header & Search
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    Text(PPAdoptLang("search"))
                        .font(AdoptFont.bold(14, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)

                    AdoptSearchField(
                        searchText: $store.searchText,
                        isFocused: searchIsFocused,
                        shortcutHint: "⌘F"
                    )
                }

                // Species Filter Cockpit
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    HStack {
                        Text(PPAdoptLang("Kind"))
                            .font(AdoptFont.bold(14, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextSecondary)

                        Spacer()

                        if store.selectedKindID != 0 {
                            Button(action: {
                                AdoptHaptics.impactLight()
                                store.selectedKindID = 0
                            }) {
                                Text(PPAdoptLang("All"))
                                    .font(AdoptFont.bold(12, relativeTo: .caption2))
                                    .foregroundStyle(Color.ppQuickActionAdoption)
                            }
                        }
                    }

                    speciesGrid
                }

                // Gender Filter Section
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    Text(PPAdoptLang("Gender"))
                        .font(AdoptFont.bold(14, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)

                    HStack(spacing: PPSpace.xs) {
                        genderSidebarTile(
                            title: PPAdoptLang("All"),
                            symbol: "pawprint.fill",
                            isSelected: store.selectedGender.isEmpty
                        ) {
                            store.selectedGender = ""
                        }

                        genderSidebarTile(
                            title: PPAdoptLang("Male"),
                            symbol: "figure.stand",
                            isSelected: store.selectedGender == "male"
                        ) {
                            store.selectedGender = store.selectedGender == "male" ? "" : "male"
                        }

                        genderSidebarTile(
                            title: PPAdoptLang("Female"),
                            symbol: "person.fill",
                            isSelected: store.selectedGender == "female"
                        ) {
                            store.selectedGender = store.selectedGender == "female" ? "" : "female"
                        }
                    }
                }

                // Adoption Intelligence & Guidance Card
                AdoptTipsCard()

                Spacer(minLength: PPSpace.xl)
            }
            .padding(PPSpace.lg)
        }
    }

    private var speciesGrid: some View {
        let kinds = (MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel]) ?? []
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: PPSpace.xs), GridItem(.flexible(), spacing: PPSpace.xs)],
            spacing: PPSpace.xs
        ) {
            // All tile
            speciesTile(
                title: PPAdoptLang("All"),
                symbol: "square.grid.2x2.fill",
                count: store.pets.filter { $0.visibility == 0 }.count,
                isSelected: store.selectedKindID == 0
            ) {
                store.selectedKindID = 0
            }

            ForEach(kinds, id: \.id) { kind in
                let name = kind.kindName
                if !name.isEmpty {
                    let count = store.pets.filter { $0.visibility == 0 && $0.kindID == kind.id }.count
                    speciesTile(
                        title: name,
                        symbol: symbolForKind(name: name),
                        count: count,
                        isSelected: store.selectedKindID == kind.id
                    ) {
                        store.selectedKindID = store.selectedKindID == kind.id ? 0 : kind.id
                    }
                }
            }
        }
    }

    private func speciesTile(
        title: String,
        symbol: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            AdoptHaptics.selection()
            action()
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : Color.ppQuickActionAdoption)

                    Spacer()

                    Text("\(count)")
                        .font(AdoptFont.bold(11, relativeTo: .caption2))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.ppTextSecondary)
                }

                Text(title)
                    .font(AdoptFont.bold(13, relativeTo: .subheadline))
                    .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)
                    .lineLimit(1)
            }
            .padding(PPSpace.sm)
            .background(
                isSelected
                    ? Color.ppQuickActionAdoption
                    : Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.ppQuickActionAdoption
                            : Color.ppBorder.opacity(0.6),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            }
        }
        .buttonStyle(AdoptPressStyle(pressedScale: 0.97))
    }

    private func genderSidebarTile(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            AdoptHaptics.selection()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(AdoptFont.bold(12, relativeTo: .caption))
            }
            .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                isSelected
                    ? Color.ppQuickActionAdoption
                    : Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.ppQuickActionAdoption : Color.ppBorder.opacity(0.6),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            }
        }
        .buttonStyle(AdoptPressStyle())
    }
}

// MARK: - iPad Canvas Gallery

private struct AdoptPetCanvasGallery: View {
    @ObservedObject var store: AdoptPetListStore
    var onSelectPet: (AdoptPetModel) -> Void
    var onAddPet: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PPSpace.xl) {
                // Canvas Header
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PPAdoptLang("adopt_list_title"))
                            .font(AdoptFont.bold(26, relativeTo: .title))
                            .foregroundStyle(Color.ppTextPrimary)

                        Text(PPAdoptLang("adopt_list_results_subtitle"))
                            .font(AdoptFont.regular(14, relativeTo: .subheadline))
                            .foregroundStyle(Color.ppTextSecondary)
                    }

                    Spacer()

                    if store.hasActiveFilters {
                        Button(action: {
                            AdoptHaptics.impactLight()
                            store.clearFilters()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(PPAdoptLang("ClearFilters"))
                                    .font(AdoptFont.bold(13, relativeTo: .subheadline))
                            }
                            .foregroundStyle(Color.ppQuickActionAdoption)
                            .padding(.horizontal, PPSpace.md)
                            .padding(.vertical, 6)
                            .background(Color.ppQuickActionAdoption.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(AdoptPressStyle())
                    }
                }
                .padding(.horizontal, PPSpace.xl)
                .padding(.top, PPSpace.xl)

                if store.hasStaleConnectionIssue || (store.isRefreshing && !store.pets.isEmpty) {
                    AdoptCachedBanner(store: store)
                        .padding(.horizontal, PPSpace.xl)
                }

                // Grid Content States
                Group {
                    if store.isLoading && store.pets.isEmpty {
                        AdoptPetSkeletonView(isPad: true)
                            .padding(.horizontal, PPSpace.xl)
                    } else if store.isOffline && store.pets.isEmpty {
                        AdoptPetStatePanel(
                            symbol: "wifi.slash",
                            tint: .ppWarning,
                            title: PPAdoptLang("adopt_list_error_title"),
                            message: PPAdoptLang("adopt_list_error_subtitle"),
                            primaryTitle: PPAdoptLang("Retry"),
                            primarySymbol: "arrow.clockwise",
                            primaryAction: { store.requestRefresh() }
                        )
                        .padding(.horizontal, PPSpace.xl)
                    } else if store.pets.isEmpty {
                        AdoptPetStatePanel(
                            symbol: "heart.circle.fill",
                            tint: .ppQuickActionAdoption,
                            title: PPAdoptLang("adopt_list_empty_title"),
                            message: PPAdoptLang("adopt_list_empty_subtitle"),
                            primaryTitle: PPAdoptLang("adopt_list_add_action"),
                            primarySymbol: "plus",
                            primaryAction: onAddPet
                        )
                        .padding(.horizontal, PPSpace.xl)
                    } else if store.filteredPets.isEmpty {
                        AdoptPetStatePanel(
                            symbol: "magnifyingglass",
                            tint: .ppQuickActionAdoption,
                            title: PPAdoptLang("adopt_list_no_results_title"),
                            message: PPAdoptLang("adopt_list_no_results_subtitle"),
                            primaryTitle: PPAdoptLang("ClearFilters"),
                            primarySymbol: "arrow.counterclockwise",
                            primaryAction: { store.clearFilters() }
                        )
                        .padding(.horizontal, PPSpace.xl)
                    } else {
                        ipadCardsGrid
                            .padding(.horizontal, PPSpace.xl)
                    }
                }

                Spacer(minLength: PPSpace.xxxxl)
            }
        }
        .refreshable {
            await store.refresh()
        }
    }

    private var ipadCardsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 280, maximum: 400), spacing: PPSpace.lg, alignment: .top)
            ],
            spacing: PPSpace.lg
        ) {
            ForEach(store.filteredPets, id: \.documentID) { pet in
                Button(action: {
                    AdoptHaptics.impactLight()
                    onSelectPet(pet)
                }) {
                    AdoptPetCompanionCard(
                        pet: pet,
                        isCompact: false
                    )
                }
                .buttonStyle(AdoptPressStyle(pressedScale: 0.985))
                .hoverEffect(.lift)
                .accessibilityLabel(cardAccessibilityLabel(for: pet))
                .onAppear { store.loadNextIfNeeded(current: pet) }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Lead Pet Card ("First Hello")
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetLeadCard: View {
    let pet: AdoptPetModel
    let usesSplitLayout: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media Container with Floating Badges
            ZStack(alignment: .top) {
                AdoptPetMediaView(pet: pet)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 280 : 250)
                    .frame(maxWidth: .infinity)

                // Top Floating Badges
                HStack {
                    // Availability Status Pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text(PPAdoptLang("adopt_detail_available_now"))
                            .font(AdoptFont.bold(12, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.ppSurface.opacity(0.92), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
                    }

                    Spacer()

                    // Quick Favorite Heart Badge
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .frame(width: 36, height: 36)
                        .background(Color.ppSurface.opacity(0.92), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
                        }
                }
                .padding(PPSpace.md)
            }

            // Body Info
            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(adoptPetTitle(pet))
                            .font(AdoptFont.bold(22, relativeTo: .title2))
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.ppQuickActionAdoption)

                            Text(adoptPetSubtitle(pet))
                                .font(AdoptFont.medium(14, relativeTo: .subheadline))
                                .foregroundStyle(Color.ppTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                // Facts Rail (Age, Gender, Kind)
                let facts = adoptPetFacts(pet)
                if !facts.isEmpty {
                    HStack(spacing: PPSpace.xs) {
                        ForEach(facts) { fact in
                            HStack(spacing: 4) {
                                Image(systemName: fact.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.ppQuickActionAdoption)
                                Text(fact.title)
                                    .font(AdoptFont.medium(12, relativeTo: .caption))
                                    .foregroundStyle(Color.ppTextPrimary)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.small))
                        }
                        Spacer(minLength: 0)
                    }
                }

                // Story Preview Snippet
                if !pet.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(pet.details.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(AdoptFont.regular(13, relativeTo: .footnote))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                // Action Bar
                HStack(spacing: 6) {
                    Text(PPAdoptLang("adopt_list_view_profile"))
                        .font(AdoptFont.bold(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.white)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.ppQuickActionAdoption, in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
            }
            .padding(PPSpace.lg)
        }
        .background(Color.ppSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.ppTextPrimary.opacity(0.6)
                        : Color.ppBorder.opacity(0.78),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06),
            radius: 14,
            y: 6
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Companion Pet Card
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetCompanionCard: View {
    let pet: AdoptPetModel
    let isCompact: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if isCompact {
                // Horizontal Split on iPhone
                HStack(spacing: 0) {
                    AdoptPetMediaView(pet: pet)
                        .frame(width: 120, height: 148)
                        .clipped()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(adoptPetTitle(pet))
                            .font(AdoptFont.bold(17, relativeTo: .headline))
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.ppQuickActionAdoption)
                            Text(adoptPetSubtitle(pet))
                                .font(AdoptFont.medium(12, relativeTo: .caption))
                                .foregroundStyle(Color.ppTextSecondary)
                                .lineLimit(1)
                        }

                        let facts = adoptPetFacts(pet)
                        if !facts.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(facts.prefix(2)) { fact in
                                    HStack(spacing: 3) {
                                        Image(systemName: fact.symbol)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.ppQuickActionAdoption)
                                        Text(fact.title)
                                            .font(AdoptFont.medium(11, relativeTo: .caption2))
                                    }
                                    .foregroundStyle(Color.ppTextPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.ppSecondarySurface, in: Capsule())
                                }
                            }
                        }

                        Spacer(minLength: 2)

                        HStack(spacing: 3) {
                            Text(PPAdoptLang("adopt_list_view_profile"))
                                .font(AdoptFont.bold(12, relativeTo: .caption))
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Color.ppQuickActionAdoption)
                    }
                    .padding(PPSpace.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // Vertical Card on iPad
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        AdoptPetMediaView(pet: pet)
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)

                        // Top Heart
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.ppQuickActionAdoption)
                            .frame(width: 32, height: 32)
                            .background(Color.ppSurface.opacity(0.9), in: Circle())
                            .padding(PPSpace.sm)
                    }

                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(adoptPetTitle(pet))
                                .font(AdoptFont.bold(18, relativeTo: .headline))
                                .foregroundStyle(Color.ppTextPrimary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.ppQuickActionAdoption)
                                Text(adoptPetSubtitle(pet))
                                    .font(AdoptFont.medium(13, relativeTo: .subheadline))
                                    .foregroundStyle(Color.ppTextSecondary)
                                    .lineLimit(1)
                            }
                        }

                        let facts = adoptPetFacts(pet)
                        if !facts.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(facts) { fact in
                                    HStack(spacing: 4) {
                                        Image(systemName: fact.symbol)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.ppQuickActionAdoption)
                                        Text(fact.title)
                                            .font(AdoptFont.medium(11, relativeTo: .caption2))
                                    }
                                    .foregroundStyle(Color.ppTextPrimary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }

                        if !pet.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(pet.details.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(AdoptFont.regular(12, relativeTo: .caption))
                                .foregroundStyle(Color.ppTextSecondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 4) {
                            Text(PPAdoptLang("adopt_list_view_profile"))
                                .font(AdoptFont.bold(13, relativeTo: .subheadline))
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(PPSpace.base)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.ppTextPrimary.opacity(0.6)
                        : Color.ppBorder.opacity(0.74),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04),
            radius: 8,
            y: 3
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Media View with Studio Illustrated Fallback
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetMediaView: View {
    let pet: AdoptPetModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let source = adoptPetCoverSource(pet) {
                    PPPetAdRemoteImageView(
                        urlString: source.urlString,
                        blurHash: source.blurHash,
                        contentMode: .fill,
                        accessibilityLabel: adoptPetTitle(pet),
                        showsRetryOnFailure: false,
                        cacheKey: source.cacheKey,
                        displaySize: proxy.size,
                        usesPetFocus: true
                    )
                } else {
                    // Studio Illustrated Warm Fallback Art
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                Color.ppSecondarySurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Circle()
                            .fill(Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.16 : 0.08))
                            .frame(width: 130, height: 130)
                            .blur(radius: 16)

                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.ppSurface.opacity(0.85))
                                    .frame(width: 56, height: 56)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color.ppQuickActionAdoption.opacity(0.24), lineWidth: 1)
                                    }

                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Color.ppQuickActionAdoption)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.ppQuickActionAdoption)
                                Text(PPAdoptLang("adopt_detail_available_now"))
                                    .font(AdoptFont.medium(11, relativeTo: .caption2))
                                    .foregroundStyle(Color.ppTextSecondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.ppSurface.opacity(0.7), in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Search Field
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptSearchField: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    var shortcutHint: String? = nil

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)

            TextField(PPAdoptLang("search"), text: $searchText)
                .font(AdoptFont.regular(15, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .focused(isFocused)
                .onSubmit {
                    isFocused.wrappedValue = false
                }

            if !searchText.isEmpty {
                Button(action: {
                    AdoptHaptics.impactLight()
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            } else if let shortcutHint {
                Text(shortcutHint)
                    .font(AdoptFont.bold(10, relativeTo: .caption2))
                    .foregroundStyle(Color.ppTextTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, PPSpace.md)
        .frame(height: 46)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(
                    isFocused.wrappedValue
                        ? Color.ppQuickActionAdoption
                        : Color.ppBorder.opacity(0.7),
                    lineWidth: isFocused.wrappedValue || colorSchemeContrast == .increased ? 1.4 : 0.8
                )
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Adoption Guidance Tips (iPad Sidebar)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptTipsCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)

                Text(PPAdoptLang("adopt_detail_section_facts"))
                    .font(AdoptFont.bold(14, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                tipRow(
                    symbol: "house.fill",
                    title: "البيئة المناسبة",
                    desc: "جهّز مساحة هادئة وآمنة تساعد رفيقك الجديد على الاستقرار."
                )

                tipRow(
                    symbol: "cross.case.fill",
                    title: "السجل الطبي",
                    desc: "تحقق من جدول التطعيمات والفحوصات البيطرية السابقة."
                )

                tipRow(
                    symbol: "heart.text.square.fill",
                    title: "بناء الثقة",
                    desc: "امنح الحيوان وقتاً كافياً للتأقلم وتكوين الألفة مع عائلتك."
                )
            }
        }
        .padding(PPSpace.base)
        .background(
            Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.14 : 0.08),
            in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppQuickActionAdoption.opacity(0.2), lineWidth: 0.8)
        }
    }

    private func tipRow(symbol: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .frame(width: 22, height: 22)
                .background(Color.ppSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AdoptFont.bold(12, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextPrimary)

                Text(desc)
                    .font(AdoptFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineSpacing(2)
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Shimmer Skeleton View (Loading State)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetSkeletonView: View {
    let isPad: Bool

    @State private var shimmerPhase: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            if !isPad {
                // Lead Card Skeleton
                VStack(alignment: .leading, spacing: 0) {
                    skeletonBox(height: 220)
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        skeletonBox(width: 140, height: 18)
                        skeletonBox(width: 100, height: 14)
                        HStack(spacing: 8) {
                            skeletonBox(width: 60, height: 22)
                            skeletonBox(width: 60, height: 22)
                        }
                    }
                    .padding(PPSpace.lg)
                }
                .skeletonCard(cornerRadius: PPCorner.hero)

                // Row Skeletons
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 0) {
                        skeletonBox(width: 120, height: 130)
                        VStack(alignment: .leading, spacing: PPSpace.xs) {
                            skeletonBox(width: 120, height: 16)
                            skeletonBox(width: 80, height: 12)
                            Spacer()
                            skeletonBox(width: 90, height: 12)
                        }
                        .padding(PPSpace.base)
                    }
                    .skeletonCard(cornerRadius: PPCorner.card)
                }
            } else {
                // iPad Multi-Column Skeletons
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: PPSpace.lg)],
                    spacing: PPSpace.lg
                ) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            skeletonBox(height: 180)
                            VStack(alignment: .leading, spacing: PPSpace.sm) {
                                skeletonBox(width: 130, height: 18)
                                skeletonBox(width: 90, height: 13)
                                HStack(spacing: 6) {
                                    skeletonBox(width: 50, height: 20)
                                    skeletonBox(width: 50, height: 20)
                                }
                            }
                            .padding(PPSpace.base)
                        }
                        .skeletonCard(cornerRadius: PPCorner.card)
                    }
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
        }
    }

    private func skeletonBox(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(height / 2, 8), style: .continuous)
            .fill(Color.ppMineralBeige.opacity(0.72))
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
    }
}

private extension View {
    func skeletonCard(cornerRadius: CGFloat) -> some View {
        background(Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
            }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: State Panel (Empty & Error)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptPetStatePanel: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let primaryTitle: String
    let primarySymbol: String
    let primaryAction: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(spacing: PPSpace.base) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 84, height: 84)

                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(AdoptFont.bold(19, relativeTo: .title3))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AdoptFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: {
                AdoptHaptics.impactMedium()
                primaryAction()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: primarySymbol)
                        .font(.system(size: 14, weight: .bold))

                    Text(primaryTitle)
                        .font(AdoptFont.bold(15, relativeTo: .headline))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.xl)
                .frame(height: 48)
                .background(
                    Color.ppQuickActionAdoption,
                    in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                )
                .overlay {
                    if colorSchemeContrast == .increased {
                        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    }
                }
            }
            .buttonStyle(AdoptPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, PPSpace.xxxl)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.ppTextPrimary.opacity(0.6)
                        : Color.ppBorder.opacity(0.76),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components: Cached Connection Banner
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AdoptCachedBanner: View {
    @ObservedObject var store: AdoptPetListStore

    var body: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: store.isOffline ? "wifi.slash" : "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 32, height: 32)
                .background(
                    (store.isOffline ? Color.ppWarning : Color.ppQuickActionAdoption).opacity(0.16),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(PPAdoptLang("adopt_list_cached_title"))
                    .font(AdoptFont.bold(13, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextPrimary)

                Text(store.isRefreshing ? PPAdoptLang("adopt_list_refreshing") : PPAdoptLang("adopt_list_cached_subtitle"))
                    .font(AdoptFont.regular(11, relativeTo: .caption2))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: {
                    AdoptHaptics.impactLight()
                    store.requestRefresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(AdoptPressStyle())
            }
        }
        .padding(PPSpace.md)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Helpers & Data Mapping
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private extension AdoptPetListStore {
    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedKindID != 0
            || !selectedGender.isEmpty
            || selectedCityID != 0
    }
}

private struct AdoptListFact: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

private func adoptPetTitle(_ pet: AdoptPetModel) -> String {
    let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? PPAdoptLang("AdoptPet") : name
}

private func adoptPetSubtitle(_ pet: AdoptPetModel) -> String {
    var parts: [String] = []
    let breed = pet.mBreedName.trimmingCharacters(in: .whitespacesAndNewlines)
    let kind = pet.mKindName.trimmingCharacters(in: .whitespacesAndNewlines)
    let city = pet.mCityName.trimmingCharacters(in: .whitespacesAndNewlines)

    if !breed.isEmpty && breed != "-" {
        parts.append(breed)
    } else if !kind.isEmpty && kind != "-" {
        parts.append(kind)
    }

    if !city.isEmpty && city != "-" {
        parts.append(city)
    }

    return parts.isEmpty
        ? PPAdoptLang("adopt_list_profile_fallback")
        : parts.joined(separator: " • ")
}

private func adoptPetFacts(_ pet: AdoptPetModel) -> [AdoptListFact] {
    var facts: [AdoptListFact] = []
    let gender = PPAdoptGenderLabel(pet.gender)
    if !gender.isEmpty {
        facts.append(AdoptListFact(id: "gender", title: gender, symbol: "figure.stand"))
    }

    if pet.ageMonths > 0 {
        let ageString = PPAdoptFormattedAge(months: pet.ageMonths)
        facts.append(AdoptListFact(id: "age", title: ageString, symbol: "calendar"))
    }

    return facts
}

private func symbolForKind(name: String) -> String {
    let lower = name.lowercased()
    if lower.contains("طير") || lower.contains("طيور") || lower.contains("bird") || lower.contains("صقر") || lower.contains("صقور") {
        return "bird.fill"
    } else if lower.contains("سمك") || lower.contains("اسماك") || lower.contains("fish") {
        return "fish.fill"
    } else if lower.contains("أرنب") || lower.contains("ارانب") || lower.contains("rabbit") {
        return "hare.fill"
    } else if lower.contains("سلحفاة") || lower.contains("سلاحف") || lower.contains("turtle") {
        return "tortoise.fill"
    }
    return "pawprint.fill"
}

private struct AdoptPetCoverSource {
    let urlString: String
    let blurHash: String?
    let cacheKey: String
}

private func adoptPetCoverSource(_ pet: AdoptPetModel) -> AdoptPetCoverSource? {
    guard let rawURL = pet.imageURLs.first?.trimmingCharacters(in: .whitespacesAndNewlines),
          !rawURL.isEmpty,
          let parsedURL = URL(string: rawURL),
          let scheme = parsedURL.scheme?.lowercased(),
          scheme == "https" || scheme == "http" else {
        return nil
    }

    let metadata = (pet.imageMeta ?? []).map { $0 as NSDictionary }
    let exactMetadata = metadata.first { item in
        adoptPetMetadataString(item, keys: ["url", "imageURL", "image_url"]) == rawURL
    }
    let alignedMetadata = metadata.count == pet.imageURLs.count ? metadata.first : nil
    let blurHash = adoptPetMetadataString(
        exactMetadata ?? alignedMetadata,
        keys: ["blurHash", "blur_hash"]
    )
    let documentID = pet.documentID.trimmingCharacters(in: .whitespacesAndNewlines)

    return AdoptPetCoverSource(
        urlString: rawURL,
        blurHash: blurHash,
        cacheKey: "adoption|\(documentID)|\(rawURL)"
    )
}

private func adoptPetMetadataString(_ metadata: NSDictionary?, keys: [String]) -> String? {
    guard let metadata else { return nil }
    for key in keys {
        guard let value = metadata[key] as? String else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return nil
}

private func cardAccessibilityLabel(for pet: AdoptPetModel) -> String {
    var parts = [adoptPetTitle(pet)]
    if adoptPetCoverSource(pet) == nil {
        parts.append(PPAdoptLang("adopt_detail_media_unavailable"))
    }
    let subtitle = adoptPetSubtitle(pet)
    if subtitle != PPAdoptLang("adopt_list_profile_fallback") {
        parts.append(subtitle)
    }
    parts.append(contentsOf: adoptPetFacts(pet).map(\.title))
    return parts.joined(separator: ", ")
}
