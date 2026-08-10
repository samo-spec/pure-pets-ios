//
//  AdoptPetListScreen.swift
//  Pure Pets
//
//  Production SwiftUI Adopt Pet List Experience.
//  Redesign: First Hello - portrait-led adoption discovery.
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
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.ppBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    navigationHeader(topInset: resolvedTopInset(proxy))
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
                withAnimation(.easeOut(duration: 0.26)) {
                    contentAppeared = true
                }
            }
        }
        .onDisappear {
            store.stopObserving()
        }
    }

    // MARK: - Navigation

    private func resolvedTopInset(_ proxy: GeometryProxy) -> CGFloat {
        let inset = proxy.safeAreaInsets.top
        if inset > 1 {
            return inset
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    private func navigationHeader(topInset: CGFloat) -> some View {
        HStack(spacing: PPSpace.md) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.ppSurface, in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(headerBorderColor, lineWidth: headerBorderWidth)
                        }
                }
                .buttonStyle(AdoptListPressStyle())
                .accessibilityLabel(PPAdoptLang("Back"))
            }

            HStack(spacing: PPSpace.sm) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .frame(width: 30, height: 30)
                    .background(Color.ppQuickActionAdoption.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                Text(PPAdoptLang("adopt_list_eyebrow"))
                    .font(PPFont.bold(14))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: PPSpace.sm)

            Button(action: onAddPet) {
                HStack(spacing: PPSpace.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))

                    if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                        Text(PPAdoptLang("adopt_list_add_action"))
                            .font(PPFont.bold(14))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(Color.ppTextPrimary)
                .padding(.horizontal, horizontalSizeClass == .regular ? PPSpace.md : 0)
                .frame(minWidth: 44, minHeight: 44)
                .background(
                    Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.20 : 0.14),
                    in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                        .strokeBorder(
                            Color.ppQuickActionAdoption.opacity(colorSchemeContrast == .increased ? 0.9 : 0.34),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                        )
                }
            }
            .buttonStyle(AdoptListPressStyle())
            .accessibilityLabel(PPAdoptLang("adopt_list_add_action"))
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, topInset + PPSpace.sm)
        .padding(.bottom, PPSpace.sm)
        .background(Color.ppElevatedSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ppSeparator.opacity(0.72))
                .frame(height: colorSchemeContrast == .increased ? 1 : 0.5)
                .accessibilityHidden(true)
        }
    }

    private var headerBorderColor: Color {
        colorSchemeContrast == .increased
            ? Color.ppTextPrimary.opacity(0.6)
            : Color.ppBorder.opacity(0.78)
    }

    private var headerBorderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 0.8
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: PPSpace.xl) {
                introduction

                if shouldShowDiscoveryControls {
                    discoveryControls
                }

                if store.hasStaleConnectionIssue || (store.isRefreshing && !store.pets.isEmpty) {
                    cachedConnectionBanner
                }

                stateContent
            }
            .padding(.horizontal, PPSpace.screenMargin)
            .padding(.top, PPSpace.xl)
            .padding(.bottom, PPSpace.xxxxl)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .refreshable {
            await store.refresh()
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(PPAdoptLang("adopt_list_title"))
                .font(PPFont.largeTitle())
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(PPAdoptLang("adopt_list_subtitle"))
                .font(PPFont.body())
                .foregroundStyle(Color.ppTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared || reduceMotion ? 0 : 8)
    }

    private var shouldShowDiscoveryControls: Bool {
        !store.pets.isEmpty || store.hasActiveFilters
    }

    // MARK: - Discovery Controls

    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
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

                    if let kinds = MainKindsArrayManager.shared().mainKindsArray as? [MainKindsModel] {
                        ForEach(kinds, id: \.id) { kind in
                            let title = kind.kindName
                            if !title.isEmpty {
                                filterChip(
                                    title: title,
                                    symbol: "pawprint.fill",
                                    isSelected: store.selectedKindID == kind.id
                                ) {
                                    store.selectedKindID = store.selectedKindID == kind.id ? 0 : kind.id
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)

            TextField(PPAdoptLang("search"), text: $store.searchText)
                .font(PPFont.callout())
                .foregroundStyle(Color.ppTextPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .focused($searchIsFocused)
                .onSubmit {
                    searchIsFocused = false
                }
                .accessibilityLabel(PPAdoptLang("search"))

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.ppTextTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(PPAdoptLang("adopt_list_clear_search"))
            }
        }
        .padding(.horizontal, PPSpace.md)
        .frame(minHeight: 50)
        .background(
            Color.ppSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(headerBorderColor, lineWidth: headerBorderWidth)
        }
        .accessibilityElement(children: .contain)
    }

    private func filterChip(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            HStack(spacing: PPSpace.xs) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(PPFont.bold(13))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, PPSpace.md)
            .frame(minHeight: 44)
            .background(
                isSelected
                    ? Color.ppQuickActionAdoption.opacity(colorScheme == .dark ? 0.24 : 0.16)
                    : Color.ppSurface,
                in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.ppQuickActionAdoption.opacity(colorSchemeContrast == .increased ? 1 : 0.66)
                            : Color.ppBorder.opacity(0.82),
                        lineWidth: isSelected || colorSchemeContrast == .increased ? 1.4 : 0.8
                    )
            }
        }
        .buttonStyle(AdoptListPressStyle(pressedScale: 0.97))
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(filterAnimation, value: isSelected)
    }

    // MARK: - States

    @ViewBuilder
    private var stateContent: some View {
        if store.isLoading && store.pets.isEmpty {
            loadingState
        } else if store.isOffline && store.pets.isEmpty {
            offlineState
        } else if let message = store.errorMessage,
                  store.pets.isEmpty,
                  !store.isOffline {
            errorState(message: message)
        } else if store.filteredPets.isEmpty {
            emptyState
        } else {
            populatedContent
        }
    }

    private var populatedContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            resultsHeading

            if let leadPet = store.filteredPets.first {
                Button {
                    onSelectPet(leadPet)
                } label: {
                    AdoptPetLeadCard(
                        pet: leadPet,
                        usesSplitLayout: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
                    )
                }
                .buttonStyle(AdoptListPressStyle(pressedScale: 0.99))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(cardAccessibilityLabel(for: leadPet))
                .accessibilityHint(PPAdoptLang("adopt_list_open_profile_hint"))
                .accessibilityAddTraits(.isButton)
            }

            if store.filteredPets.count > 1 {
                Text(PPAdoptLang("adopt_list_more_title"))
                    .font(PPFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .padding(.top, PPSpace.sm)
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: resultColumns, spacing: PPSpace.md) {
                    ForEach(store.filteredPets.dropFirst(), id: \.documentID) { pet in
                        Button {
                            onSelectPet(pet)
                        } label: {
                            AdoptPetProfileCard(
                                pet: pet,
                                usesVerticalLayout: horizontalSizeClass == .regular || dynamicTypeSize.isAccessibilitySize
                            )
                        }
                        .buttonStyle(AdoptListPressStyle(pressedScale: 0.985))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(cardAccessibilityLabel(for: pet))
                        .accessibilityHint(PPAdoptLang("adopt_list_open_profile_hint"))
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared || reduceMotion ? 0 : 10)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: contentAppeared)
    }

    private var resultColumns: [GridItem] {
        let count = horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize ? 2 : 1
        return Array(
            repeating: GridItem(.flexible(), spacing: PPSpace.md, alignment: .top),
            count: count
        )
    }

    private var resultsHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(PPAdoptLang("adopt_list_results_title"))
                    .font(PPFont.title3())
                    .foregroundStyle(Color.ppTextPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    store.hasActiveFilters
                        ? String(format: PPAdoptLang("adopt_list_filtered_count_format"), store.filteredPets.count)
                        : PPAdoptLang("adopt_list_results_subtitle")
                )
                .font(PPFont.caption1())
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: PPSpace.sm)

            if store.hasActiveFilters {
                Button {
                    store.clearFilters()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.ppQuickActionAdoption.opacity(0.14), in: Circle())
                }
                .buttonStyle(AdoptListPressStyle())
                .accessibilityLabel(PPAdoptLang("ClearFilters"))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var loadingState: some View {
        AdoptPetListSkeleton(
            usesSplitLead: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize,
            usesVerticalRows: horizontalSizeClass == .regular || dynamicTypeSize.isAccessibilitySize,
            usesTwoColumnRows: horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PPAdoptLang("adopt_list_loading"))
    }

    private var emptyState: some View {
        let hasFilters = store.hasActiveFilters
        return AdoptListStatePanel(
            symbol: hasFilters ? "magnifyingglass" : "heart.slash",
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
            primarySymbol: hasFilters ? "line.3.horizontal.decrease" : "arrow.clockwise",
            primaryAction: {
                if hasFilters {
                    store.clearFilters()
                } else {
                    store.requestRefresh()
                }
            }
        )
    }

    private var offlineState: some View {
        AdoptListStatePanel(
            symbol: "wifi.slash",
            tint: .ppWarning,
            title: PPAdoptLang("adopt_list_error_title"),
            message: PPAdoptLang("adopt_list_error_subtitle"),
            primaryTitle: PPAdoptLang("Retry"),
            primarySymbol: "arrow.clockwise",
            primaryAction: { store.requestRefresh() }
        )
    }

    private func errorState(message: String) -> some View {
        AdoptListStatePanel(
            symbol: "exclamationmark.triangle.fill",
            tint: .ppError,
            title: PPAdoptLang("adopt_list_error_title"),
            message: message.isEmpty ? PPAdoptLang("adopt_list_error_subtitle") : message,
            primaryTitle: PPAdoptLang("Retry"),
            primarySymbol: "arrow.clockwise",
            primaryAction: { store.requestRefresh() }
        )
    }

    private var cachedConnectionBanner: some View {
        HStack(alignment: .center, spacing: PPSpace.sm) {
            Image(systemName: store.isOffline ? "wifi.slash" : "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ppTextPrimary)
                .frame(width: 34, height: 34)
                .background(
                    (store.isOffline ? Color.ppWarning : Color.ppQuickActionAdoption).opacity(0.16),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(PPAdoptLang("adopt_list_cached_title"))
                    .font(PPFont.medium(13))
                    .foregroundStyle(Color.ppTextPrimary)

                Text(
                    store.isRefreshing
                        ? PPAdoptLang("adopt_list_refreshing")
                        : PPAdoptLang("adopt_list_cached_subtitle")
                )
                .font(PPFont.caption2())
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: PPSpace.xs)

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(PPAdoptLang("adopt_list_refreshing"))
            } else {
                Button {
                    store.requestRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ppTextPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AdoptListPressStyle())
                .accessibilityLabel(PPAdoptLang("Retry"))
            }
        }
        .padding(PPSpace.md)
        .background(
            Color.ppSecondarySurface,
            in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(headerBorderColor, lineWidth: headerBorderWidth)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Helpers

    private var filterAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
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
}

// MARK: - Store Helpers

private extension AdoptPetListStore {
    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedKindID != 0
            || !selectedGender.isEmpty
            || selectedCityID != 0
    }
}

// MARK: - Profile Content

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
        facts.append(AdoptListFact(id: "gender", title: gender, symbol: "person.fill"))
    }

    if pet.ageMonths > 0 {
        facts.append(
            AdoptListFact(
                id: "age",
                title: String(format: PPAdoptLang("%ld Months"), pet.ageMonths),
                symbol: "calendar"
            )
        )
    }

    return facts
}

// MARK: - Lead Profile

private struct AdoptPetLeadCard: View {
    let pet: AdoptPetModel
    let usesSplitLayout: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if usesSplitLayout {
                HStack(spacing: 0) {
                    AdoptPetListMedia(pet: pet)
                        .frame(maxWidth: .infinity)
                        .frame(height: 286)

                    profileCopy
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 286, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    AdoptPetListMedia(pet: pet)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 238 : 252)

                    profileCopy
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: cardBorderWidth)
        }
        .shadow(
            color: colorSchemeContrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.16 : 0.055),
            radius: 14,
            y: 6
        )
        .contentShape(RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
    }

    private var profileCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.sm) {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(adoptPetTitle(pet))
                        .font(PPFont.title1())
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(adoptPetSubtitle(pet))
                        .font(PPFont.subheadline())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: PPSpace.xs)

                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.ppQuickActionAdoption)
                    .frame(width: 34, height: 34)
                    .background(Color.ppQuickActionAdoption.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
            }

            factRail

            HStack(spacing: PPSpace.xs) {
                Text(PPAdoptLang("adopt_list_view_profile"))
                    .font(PPFont.bold(14))
                    .foregroundStyle(Color.ppTextPrimary)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppTextSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PPSpace.lg)
    }

    @ViewBuilder
    private var factRail: some View {
        let facts = adoptPetFacts(pet)
        if !facts.isEmpty {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    ForEach(facts) { fact in
                        factView(fact)
                    }
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    ForEach(facts) { fact in
                        factView(fact)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func factView(_ fact: AdoptListFact) -> some View {
        HStack(spacing: 6) {
            Image(systemName: fact.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.ppQuickActionAdoption)
                .accessibilityHidden(true)
            Text(fact.title)
                .font(PPFont.medium(13))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }

    private var cardBorderColor: Color {
        colorSchemeContrast == .increased
            ? Color.ppTextPrimary.opacity(0.62)
            : Color.ppBorder.opacity(0.84)
    }

    private var cardBorderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 0.8
    }
}

// MARK: - Supporting Profiles

private struct AdoptPetProfileCard: View {
    let pet: AdoptPetModel
    let usesVerticalLayout: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Group {
            if usesVerticalLayout {
                VStack(alignment: .leading, spacing: 0) {
                    AdoptPetListMedia(pet: pet)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 182)

                    profileCopy
                }
            } else {
                HStack(spacing: 0) {
                    AdoptPetListMedia(pet: pet)
                        .frame(width: 124, height: 164)

                    profileCopy
                        .frame(minHeight: 164)
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
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder.opacity(0.84),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
        .shadow(
            color: colorSchemeContrast == .increased
                ? .clear
                : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
            radius: 10,
            y: 4
        )
        .contentShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
    }

    private var profileCopy: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(adoptPetTitle(pet))
                    .font(PPFont.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(adoptPetSubtitle(pet))
                    .font(PPFont.caption1())
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let facts = adoptPetFacts(pet)
            if !facts.isEmpty {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        ForEach(facts) { fact in
                            profileFact(fact)
                        }
                    }
                } else {
                    HStack(spacing: PPSpace.md) {
                        ForEach(facts) { fact in
                            profileFact(fact)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: PPSpace.xs) {
                Text(PPAdoptLang("adopt_list_view_profile"))
                    .font(PPFont.bold(13))
                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.ppTextPrimary)
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func profileFact(_ fact: AdoptListFact) -> some View {
        HStack(spacing: 5) {
            Image(systemName: fact.symbol)
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
            Text(fact.title)
                .font(PPFont.medium(12))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
        .foregroundStyle(Color.ppTextSecondary)
    }
}

// MARK: - Media

private struct AdoptPetListMedia: View {
    let pet: AdoptPetModel

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
                    ZStack {
                        Color.ppSecondarySurface

                        VStack(spacing: PPSpace.sm) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(Color.ppQuickActionAdoption.opacity(0.62))
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.ppTextTertiary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
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

// MARK: - Loading

private struct AdoptPetListSkeleton: View {
    let usesSplitLead: Bool
    let usesVerticalRows: Bool
    let usesTwoColumnRows: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack {
                skeletonLine(width: 168, height: 20)
                Spacer()
            }

            leadPlaceholder

            HStack {
                skeletonLine(width: 128, height: 16)
                Spacer()
            }
            .padding(.top, PPSpace.sm)

            LazyVGrid(
                columns: usesTwoColumnRows
                    ? [GridItem(.flexible()), GridItem(.flexible())]
                    : [GridItem(.flexible())],
                spacing: PPSpace.md
            ) {
                ForEach(0..<4, id: \.self) { _ in
                    rowPlaceholder
                }
            }
        }
    }

    @ViewBuilder
    private var leadPlaceholder: some View {
        if usesSplitLead {
            HStack(spacing: 0) {
                mediaBlock
                    .frame(maxWidth: .infinity)
                    .frame(height: 286)
                copyBlock
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 286)
            }
            .skeletonCard(cornerRadius: PPCorner.hero)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                mediaBlock
                    .frame(height: 252)
                copyBlock
            }
            .skeletonCard(cornerRadius: PPCorner.hero)
        }
    }

    @ViewBuilder
    private var rowPlaceholder: some View {
        if usesVerticalRows {
            VStack(alignment: .leading, spacing: 0) {
                mediaBlock
                    .frame(height: 182)
                copyBlock
            }
            .skeletonCard(cornerRadius: PPCorner.card)
        } else {
            HStack(spacing: 0) {
                mediaBlock
                    .frame(width: 124, height: 164)
                copyBlock
                    .frame(minHeight: 164)
            }
            .skeletonCard(cornerRadius: PPCorner.card)
        }
    }

    private var mediaBlock: some View {
        Rectangle()
            .fill(Color.ppSecondarySurface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            skeletonLine(width: 132, height: 16)
            skeletonLine(width: 102, height: 12)
            skeletonLine(width: 156, height: 12)
            Spacer(minLength: PPSpace.sm)
            skeletonLine(width: 88, height: 12)
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(height / 2, 6), style: .continuous)
            .fill(Color.ppMineralBeige.opacity(0.82))
            .frame(maxWidth: width)
            .frame(height: height)
    }
}

private extension View {
    func skeletonCard(cornerRadius: CGFloat) -> some View {
        background(Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ppBorder.opacity(0.74), lineWidth: 0.8)
            }
    }
}

// MARK: - Empty / Error

private struct AdoptListStatePanel: View {
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
                    .fill(tint.opacity(0.14))
                    .frame(width: 88, height: 88)
                Image(systemName: symbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: PPSpace.sm) {
                Text(title)
                    .font(PPFont.title3())
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(PPFont.subheadline())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: primaryAction) {
                HStack(spacing: PPSpace.sm) {
                    Image(systemName: primarySymbol)
                        .font(.system(size: 14, weight: .bold))
                    Text(primaryTitle)
                        .font(PPFont.bold(15))
                        .lineLimit(2)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, PPSpace.xl)
                .frame(minHeight: 48)
                .background(
                    Color.ppPrimary,
                    in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                )
                .overlay {
                    if colorSchemeContrast == .increased {
                        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1.5)
                    }
                }
            }
            .buttonStyle(AdoptListPressStyle())
            .accessibilityLabel(primaryTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PPSpace.xl)
        .padding(.vertical, PPSpace.xxxl)
        .background(
            Color.ppSurface,
            in: RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(
                    colorSchemeContrast == .increased
                        ? Color.ppTextPrimary.opacity(0.62)
                        : Color.ppBorder.opacity(0.82),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 0.8
                )
        }
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
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}
