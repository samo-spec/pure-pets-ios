//
//  AdoptPetListScreen.swift
//  Pure Pets
//
//  Production SwiftUI Adopt Pet List Experience.
//  Redesign: Gentle Match Studio — adoption-tinted browse surface.
//

import SwiftUI
import UIKit

// MARK: - Screen

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

    @State private var contentAppeared = false

    var body: some View {
        GeometryReader { proxy in
            let topInset = resolvedTopInset(proxy)

            ZStack(alignment: .top) {
                atmosphere
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerChrome(topInset: topInset)
                    filterRail
                    contentView
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            store.startObserving()
            guard !contentAppeared else { return }
            if reduceMotion {
                contentAppeared = true
            } else {
                withAnimation(.easeOut(duration: 0.28)) {
                    contentAppeared = true
                }
            }
        }
        .onDisappear {
            store.stopObserving()
        }
    }

    // MARK: - Safe Area

    /// Top safe-area inset (status bar / notch / Dynamic Island) so the header
    /// background can fill the top region while its content stays below it.
    private func resolvedTopInset(_ proxy: GeometryProxy) -> CGFloat {
        let resolved = proxy.safeAreaInsets.top
        if resolved > 1 {
            return resolved
        }
        // Fallback when the hosting surface has already consumed the top inset
        // (e.g. a container ignoring safe area). Reads the key window's status
        // bar region so the header still sits below the notch / Dynamic Island.
        let sceneTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
        return sceneTop
    }

    // MARK: - Atmosphere

    private var atmosphere: some View {
        ZStack {
            Color.ppBackground

            if colorSchemeContrast != .increased {
                LinearGradient(
                    colors: [
                        Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.16 : 0.10),
                        Color.ppSoftRose.opacity(colorScheme == .dark ? 0.08 : 0.18),
                        Color.ppBackground.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.10 : 0.06),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: 280
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Header

    private func headerChrome(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .center, spacing: PPSpace.md) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.ppTextPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.ppSurface.opacity(0.92), in: Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(AdoptListPressStyle())
                    .accessibilityLabel(PPAdoptLang("Back"))
                }

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    HStack(spacing: PPSpace.xs) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.ppQuickActionAdoption)
                            .accessibilityHidden(true)

                        Text(PPAdoptLang("adopt_list_eyebrow"))
                            .font(PPFont.bold(12))
                            .foregroundStyle(Color.ppQuickActionAdoption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                    }

                    Text(PPAdoptLang("adopt_list_title"))
                        .font(PPFont.title2())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: PPSpace.sm)

                Button(action: onAddPet) {
                    HStack(spacing: PPSpace.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        if !usesCompactHeader {
                            Text(PPAdoptLang("adopt_list_add_action"))
                                .font(PPFont.bold(14))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, usesCompactHeader ? PPSpace.md : PPSpace.base)
                    .frame(minHeight: 44)
                    .background(PPGradient.hero, in: Capsule())
                    .shadow(
                        color: Color.ppPrimary.opacity(colorSchemeContrast == .increased ? 0 : 0.22),
                        radius: 10,
                        y: 4
                    )
                }
                .buttonStyle(AdoptListPressStyle())
                .accessibilityLabel(PPAdoptLang("adopt_list_add_action"))
            }

            HStack(alignment: .top, spacing: PPSpace.sm) {
                Text(PPAdoptLang("adopt_list_subtitle"))
                    .font(PPFont.subheadline())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if store.hasReceivedInitialSnapshot && !store.isLoading {
                    Text(String(format: PPAdoptLang("adopt_list_count_format"), store.filteredPets.count))
                        .font(PPFont.bold(12))
                        .foregroundStyle(Color.ppQuickActionAdoption)
                        .padding(.horizontal, PPSpace.sm)
                        .padding(.vertical, PPSpace.xs)
                        .background(
                            Color.ppQuickActionAdoption.opacity(0.14),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Color.ppQuickActionAdoption.opacity(0.22),
                                    lineWidth: 0.8
                                )
                        )
                        .accessibilityLabel(
                            String(format: PPAdoptLang("adopt_list_count_format"), store.filteredPets.count)
                        )
                        .animation(countAnimation, value: store.filteredPets.count)
                }
            }
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, topInset + PPSpace.md)
        .padding(.bottom, PPSpace.base)
        .background(
            Color.ppElevatedSurface.opacity(colorScheme == .dark ? 0.88 : 0.94)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.55))
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared || reduceMotion ? 0 : -8)
    }

    private var usesCompactHeader: Bool {
        dynamicTypeSize.isAccessibilitySize || UIScreen.main.bounds.width < 360
    }

    // MARK: - Filter Rail

    private var filterRail: some View {
        VStack(spacing: PPSpace.md) {
            searchField

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    filterChip(
                        title: PPAdoptLang("All"),
                        symbol: "square.grid.2x2.fill",
                        isSelected: !store.hasActiveFilters
                    ) {
                        store.clearFilters()
                    }

                    filterChip(
                        title: PPAdoptLang("Male"),
                        symbol: "figure.stand",
                        isSelected: store.selectedGender == "male"
                    ) {
                        store.selectedGender = store.selectedGender == "male" ? "" : "male"
                    }

                    filterChip(
                        title: PPAdoptLang("Female"),
                        symbol: "person.fill",
                        isSelected: store.selectedGender == "female"
                    ) {
                        store.selectedGender = store.selectedGender == "female" ? "" : "female"
                    }

                    if let allKinds = MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel] {
                        ForEach(allKinds, id: \.id) { kind in
                            let name = kind.kindName
                            if !name.isEmpty {
                                filterChip(
                                    title: name,
                                    symbol: "pawprint.fill",
                                    isSelected: store.selectedKindID == kind.id
                                ) {
                                    store.selectedKindID = store.selectedKindID == kind.id ? 0 : kind.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.vertical, PPSpace.xxs)
            }
        }
        .padding(.top, PPSpace.md)
        .padding(.bottom, PPSpace.sm)
        .background(Color.ppElevatedSurface.opacity(colorScheme == .dark ? 0.72 : 0.82))
    }

    private var searchField: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
                .accessibilityHidden(true)

            TextField(PPAdoptLang("search"), text: $store.searchText)
                .font(PPFont.callout())
                .foregroundStyle(Color.ppTextPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PPAdoptLang("ClearFilters"))
            }
        }
        .padding(.horizontal, PPSpace.md)
        .frame(minHeight: 48)
        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.8), lineWidth: 0.8)
        )
        .padding(.horizontal, PPSpace.screenMargin)
        .accessibilityElement(children: .combine)
    }

    private func filterChip(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
            action()
        }) {
            HStack(spacing: PPSpace.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(PPFont.bold(13))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)
            .padding(.horizontal, PPSpace.md)
            .frame(minHeight: 36)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.ppQuickActionAdoption)
                    } else {
                        Capsule().fill(Color.ppSurface)
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? Color.ppQuickActionAdoption.opacity(0.01)
                            : Color.ppBorder.opacity(0.85),
                        lineWidth: 0.9
                    )
            )
            .shadow(
                color: isSelected && colorSchemeContrast != .increased
                    ? Color.ppQuickActionAdoption.opacity(0.24)
                    : .clear,
                radius: 8,
                y: 3
            )
            .scaleEffect(isSelected && !reduceMotion ? 1.03 : 1.0)
            .animation(chipAnimation, value: isSelected)
        }
        .buttonStyle(AdoptListPressStyle(pressedScale: 0.97))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if store.isLoading && !store.hasReceivedInitialSnapshot {
            loadingSkeletonState
        } else if store.isOffline && store.pets.isEmpty {
            offlineErrorState
        } else if let message = store.errorMessage,
                  store.pets.isEmpty,
                  !store.isOffline {
            genericErrorState(message: message)
        } else if store.filteredPets.isEmpty {
            emptyState
        } else {
            populatedGrid
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.md),
            count: columnCount
        )
    }

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize {
            return 1
        }
        if horizontalSizeClass == .regular {
            return 3
        }
        return 2
    }

    private var populatedGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: PPSpace.base) {
                ForEach(store.filteredPets, id: \.documentID) { pet in
                    Button {
                        onSelectPet(pet)
                    } label: {
                        AdoptPetGridCard(pet: pet)
                    }
                    .buttonStyle(AdoptListPressStyle(pressedScale: 0.985))
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared || reduceMotion ? 0 : 10)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.28),
                        value: contentAppeared
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(cardAccessibilityLabel(for: pet))
                    .accessibilityHint(PPAdoptLang("adopt_detail_available_now"))
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.md)
            .padding(.bottom, PPSpace.xxxl)
        }
        .refreshable {
            store.refresh()
        }
    }

    private var loadingSkeletonState: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: PPSpace.base) {
                ForEach(AdoptListSkeletonItem.placeholders) { item in
                    AdoptPetGridSkeletonCard(reduceMotion: reduceMotion)
                        .id(item.id)
                }
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.md)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPAdoptLang("adopt_list_loading"))
    }

    private var emptyState: some View {
        let hasFilters = store.hasActiveFilters
        return AdoptListStatePanel(
            symbol: hasFilters ? "magnifyingglass" : "heart.slash.fill",
            tint: .ppQuickActionAdoption,
            title: hasFilters
                ? PPAdoptLang("adopt_list_no_results_title")
                : PPAdoptLang("adopt_list_empty_title"),
            message: hasFilters
                ? PPAdoptLang("adopt_list_no_results_subtitle")
                : PPAdoptLang("adopt_list_empty_subtitle"),
            primaryTitle: hasFilters
                ? PPAdoptLang("ClearFilters")
                : PPAdoptLang("empty_retry_button"),
            primarySymbol: hasFilters ? "line.3.horizontal.decrease.circle" : "arrow.clockwise",
            primaryAction: {
                if hasFilters {
                    store.clearFilters()
                } else {
                    store.refresh()
                }
            }
        )
    }

    private var offlineErrorState: some View {
        AdoptListStatePanel(
            symbol: "wifi.slash",
            tint: .ppWarning,
            title: PPAdoptLang("adopt_list_error_title"),
            message: PPAdoptLang("adopt_list_error_subtitle"),
            primaryTitle: PPAdoptLang("Retry"),
            primarySymbol: "arrow.clockwise",
            primaryAction: { store.refresh() }
        )
    }

    private func genericErrorState(message: String) -> some View {
        AdoptListStatePanel(
            symbol: "exclamationmark.triangle.fill",
            tint: .ppError,
            title: PPAdoptLang("adopt_list_error_title"),
            message: message.isEmpty ? PPAdoptLang("adopt_list_error_subtitle") : message,
            primaryTitle: PPAdoptLang("Retry"),
            primarySymbol: "arrow.clockwise",
            primaryAction: { store.refresh() }
        )
    }

    // MARK: - Helpers

    private var chipAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.86)
    }

    private var countAnimation: Animation? {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.34, dampingFraction: 0.84)
    }

    private func cardAccessibilityLabel(for pet: AdoptPetModel) -> String {
        let title = pet.name.isEmpty ? PPAdoptLang("AdoptPet") : pet.name
        let breed = pet.subKindModel.subKindName
        let city = pet.mCityName
        let gender = PPAdoptLang(pet.gender)
        var parts = [title]
        if !breed.isEmpty && breed != "-" { parts.append(breed) }
        if !city.isEmpty && city != "-" { parts.append(city) }
        if !gender.isEmpty { parts.append(gender) }
        if pet.ageMonths > 0 {
            parts.append(String(format: PPAdoptLang("%ld Months"), pet.ageMonths))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Store helpers (file-local extensions keep contracts intact)

private extension AdoptPetListStore {
    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedKindID != 0
            || !selectedGender.isEmpty
            || selectedCityID != 0
    }
}

// MARK: - Grid Card

private struct AdoptPetGridCard: View {
    let pet: AdoptPetModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: String {
        pet.name.isEmpty ? PPAdoptLang("AdoptPet") : pet.name
    }

    private var subtitle: String {
        let breed = pet.subKindModel.subKindName
        let city = pet.mCityName
        let parts = [breed, city].filter { !$0.isEmpty && $0 != "-" }
        return parts.isEmpty ? PPAdoptLang("adopt_detail_available_now") : parts.joined(separator: " • ")
    }

    private var genderLabel: String {
        let raw = pet.gender.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        return PPAdoptLang(raw)
    }

    private var mediaHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 188 : 156
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                media

                LinearGradient(
                    colors: [
                        .black.opacity(0),
                        .black.opacity(colorScheme == .dark ? 0.55 : 0.42)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 72)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                HStack(spacing: PPSpace.xs) {
                    Text(PPAdoptLang("adopt_detail_available_now"))
                        .font(PPFont.bold(10))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, PPSpace.sm)
                        .padding(.vertical, 5)
                        .background(Color.ppQuickActionAdoption.opacity(0.92), in: Capsule())
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(PPSpace.sm)
            }
            .frame(maxWidth: .infinity)
            .frame(height: mediaHeight)
            .clipped()

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(title)
                    .font(PPFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(PPFont.caption1())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metaChipRow
            }
            .padding(.horizontal, PPSpace.md)
            .padding(.top, PPSpace.md)
            .padding(.bottom, PPSpace.md)
        }
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(
                    Color.ppBorder.opacity(colorSchemeContrast == .increased ? 1 : 0.85),
                    lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.7
                )
        )
        .shadow(
            color: colorSchemeContrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.18 : 0.06),
            radius: 16,
            y: 8
        )
    }

    @ViewBuilder
    private var media: some View {
        if let firstImage = pet.imageURLs.first, !firstImage.isEmpty {
            AdoptPetRemoteImageView(urlString: firstImage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                PPGradient.softBrandField
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.ppQuickActionAdoption.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var metaChipRow: some View {
        let chips = metaChips
        if chips.isEmpty {
            EmptyView()
        } else {
            FlowChipRow(items: chips)
        }
    }

    private var metaChips: [AdoptMetaChip] {
        var items: [AdoptMetaChip] = []
        if !genderLabel.isEmpty {
            items.append(
                AdoptMetaChip(
                    id: "gender",
                    title: genderLabel,
                    symbol: "person.fill"
                )
            )
        }
        if pet.ageMonths > 0 {
            items.append(
                AdoptMetaChip(
                    id: "age",
                    title: String(format: PPAdoptLang("%ld Months"), pet.ageMonths),
                    symbol: "calendar"
                )
            )
        }
        return items
    }
}

private struct AdoptMetaChip: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

/// Compact single-line chip row that collapses gracefully under Dynamic Type.
private struct FlowChipRow: View {
    let items: [AdoptMetaChip]

    var body: some View {
        HStack(spacing: PPSpace.xs) {
            ForEach(items) { chip in
                HStack(spacing: 4) {
                    Image(systemName: chip.symbol)
                        .font(.system(size: 10, weight: .bold))
                    Text(chip.title)
                        .font(PPFont.bold(11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.ppQuickActionAdoption)
                .padding(.horizontal, PPSpace.sm)
                .padding(.vertical, 5)
                .background(
                    Color.ppQuickActionAdoption.opacity(0.12),
                    in: Capsule()
                )
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Skeleton

private struct AdoptListSkeletonItem: Identifiable {
    let id: String

    static let placeholders: [AdoptListSkeletonItem] = (1...6).map {
        AdoptListSkeletonItem(id: "adopt-list-skeleton-\($0)")
    }
}

private struct AdoptPetGridSkeletonCard: View {
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.ppSecondarySurface)
                .frame(height: 156)

            VStack(alignment: .leading, spacing: PPSpace.sm) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.ppMineralBeige)
                    .frame(height: 14)
                    .frame(maxWidth: 120, alignment: .leading)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.ppMineralBeige.opacity(0.8))
                    .frame(height: 12)
                    .frame(maxWidth: 88, alignment: .leading)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.ppSoftRose.opacity(0.7))
                    .frame(width: 72, height: 22)
            }
            .padding(PPSpace.md)
        }
        .background(Color.ppCard)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppBorder.opacity(0.7), lineWidth: 0.7)
        )
        .opacity(reduceMotion ? 1 : (pulse ? 0.72 : 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Empty / Error Panel

private struct AdoptListStatePanel: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let primaryTitle: String
    let primarySymbol: String
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: PPSpace.base) {
            Spacer(minLength: PPSpace.xl)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(PPFont.title3())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(PPFont.subheadline())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, PPSpace.xl)
            }

            Button(action: primaryAction) {
                HStack(spacing: PPSpace.sm) {
                    Image(systemName: primarySymbol)
                        .font(.system(size: 14, weight: .bold))
                    Text(primaryTitle)
                        .font(PPFont.bold(15))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.xl)
                .frame(minHeight: 48)
                .background(PPGradient.hero, in: Capsule())
            }
            .buttonStyle(AdoptListPressStyle())
            .padding(.top, PPSpace.xs)
            .accessibilityLabel(primaryTitle)

            Spacer(minLength: PPSpace.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PPSpace.screenMargin)
    }
}

// MARK: - Press Style

private struct AdoptListPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.46
                    : (configuration.isPressed ? 0.88 : 1)
            )
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.22, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}
