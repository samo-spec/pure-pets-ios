import Combine
import SwiftUI
import UIKit

enum PPProviderStorefrontL10n {
    static func text(_ key: String) -> String {
        Language.get(key, alter: key) ?? NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: Language.currentLanguageCode() ?? "ar"),
            arguments: arguments
        )
    }
}

@MainActor
final class PPProviderCompaniesStore: ObservableObject {
    enum DiscoveryMode: String, CaseIterable, Identifiable {
        case recommended
        case featured
        case topSellers
        case newest

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .recommended: return "provider_companies_discovery_recommended"
            case .featured: return "provider_companies_discovery_featured"
            case .topSellers: return "provider_companies_discovery_top_sellers"
            case .newest: return "provider_companies_discovery_newest"
            }
        }

        var symbolName: String {
            switch self {
            case .recommended: return "sparkles"
            case .featured: return "checkmark.seal.fill"
            case .topSellers: return "chart.line.uptrend.xyaxis"
            case .newest: return "clock.fill"
            }
        }
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case failed
    }

    @Published private(set) var records: [PPProviderStorefrontProviderRecord] = []
    @Published var searchQuery = ""
    @Published var discoveryMode: DiscoveryMode = .recommended
    @Published var prefersCompactLayout = false
    @Published private(set) var phase: Phase = .loading
    @Published private var favorites = Set<String>()

    private(set) var categoryIdentifier = "marketplace"
    private(set) var categoryTitleKey: String?
    private(set) var categorySubtitleKey: String?
    private var loadToken = UUID()

    var isPharmacy: Bool {
        categoryIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "pharmacy"
    }

    var categoryTitle: String {
        isPharmacy
            ? PPProviderStorefrontL10n.text("provider_pharmacies_title")
            : PPProviderStorefrontL10n.text("provider_marketplace_title")
    }

    var categorySupportText: String {
        isPharmacy
            ? PPProviderStorefrontL10n.text("provider_pharmacies_subtitle")
            : PPProviderStorefrontL10n.text("provider_marketplace_subtitle")
    }

    var visibleRecords: [PPProviderStorefrontProviderRecord] {
        var candidates = records
        let query = normalized(searchQuery)
        if !query.isEmpty {
            candidates = candidates.filter { record in
                [record.displayName, record.aboutText, record.cityText]
                    .map(normalized)
                    .contains { $0.contains(query) }
            }
        }

        if discoveryMode == .featured {
            candidates = candidates.filter(\.verified)
        }

        return candidates.sorted(by: isOrderedBefore)
    }

    var hasActiveFilter: Bool {
        !normalized(searchQuery).isEmpty || discoveryMode == .featured
    }

    func configure(
        categoryIdentifier: String,
        categoryTitleKey: String?,
        categorySubtitleKey: String?
    ) {
        let normalizedIdentifier = categoryIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedIdentifier = normalizedIdentifier.isEmpty
            ? "marketplace"
            : normalizedIdentifier
        let changed = self.categoryIdentifier != resolvedIdentifier

        self.categoryIdentifier = resolvedIdentifier
        self.categoryTitleKey = categoryTitleKey
        self.categorySubtitleKey = categorySubtitleKey
        if changed {
            records = []
            searchQuery = ""
            discoveryMode = .recommended
            favorites = []
        }
    }

    func load() {
        let token = UUID()
        loadToken = token
        phase = .loading

        PPProviderStorefrontDataBridge.fetchProviderRecords(
            categoryIdentifier: categoryIdentifier
        ) { [weak self] records, error in
            DispatchQueue.main.async {
                guard let self, self.loadToken == token else { return }
                self.records = records
                if records.isEmpty {
                    self.phase = error == nil ? .empty : .failed
                } else {
                    self.phase = .loaded
                }
            }
        }
    }

    func retry() {
        load()
    }

    func toggleFavorite(for providerID: String) {
        if favorites.contains(providerID) {
            favorites.remove(providerID)
        } else {
            favorites.insert(providerID)
        }
    }

    func isFavorite(_ providerID: String) -> Bool {
        favorites.contains(providerID)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func isOrderedBefore(
        _ left: PPProviderStorefrontProviderRecord,
        _ right: PPProviderStorefrontProviderRecord
    ) -> Bool {
        let leftDate = left.latestCreatedAt as Date? ?? .distantPast
        let rightDate = right.latestCreatedAt as Date? ?? .distantPast

        switch discoveryMode {
        case .newest:
            if leftDate != rightDate { return leftDate > rightDate }
            if left.verified != right.verified { return left.verified }
            if left.productCount != right.productCount {
                return left.productCount > right.productCount
            }
        case .topSellers:
            if left.productCount != right.productCount {
                return left.productCount > right.productCount
            }
            if left.verified != right.verified { return left.verified }
            if leftDate != rightDate { return leftDate > rightDate }
        case .recommended, .featured:
            if left.verified != right.verified { return left.verified }
            if left.productCount != right.productCount {
                return left.productCount > right.productCount
            }
            if leftDate != rightDate { return leftDate > rightDate }
        }

        return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
    }
}

// MARK: - Screen View

struct PPProviderCompaniesScreen: View {
    @ObservedObject var store: PPProviderCompaniesStore
    let onOpenStorefront: (PPProviderStorefrontProviderRecord) -> Void
    var onDismiss: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            discoveryHeader
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    discoveryFilterPills
                    content
                }
                .padding(.horizontal, PPSpace.base)
                .padding(.top, PPSpace.md)
                .padding(.bottom, PPSpace.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .animation(
            reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88),
            value: store.prefersCompactLayout
        )
        .accessibilityIdentifier("providerCompaniesSwiftUIScreen")
    }

    private var discoveryHeader: some View {
        VStack(spacing: PPSpace.sm) {
            HStack(spacing: PPSpace.sm) {
                if let onDismiss = onDismiss {
                    Button {
                        if !reduceMotion {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(Color.ppTextPrimary)
                            .background(Color.ppSurface, in: Circle())
                            .overlay {
                                Circle().stroke(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(PPProviderStorefrontL10n.text("Back"))
                }

                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    HStack(spacing: 6) {
                        Text(store.categoryTitle)
                            .font(.custom("Beiruti-Bold", size: 24, relativeTo: .title2))
                            .foregroundStyle(Color.ppTextPrimary)
                            .lineLimit(1)

                        Image(systemName: store.isPharmacy ? "cross.case.fill" : "storefront.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.ppPrimary)
                    }

                    Text(store.categorySupportText)
                        .font(.custom("Beiruti-Regular", size: 13.5, relativeTo: .subheadline))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: PPSpace.sm)

                layoutToggle
            }

            // Search Bar with Frosted Glass Morph
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
                    .accessibilityHidden(true)

                TextField(
                    PPProviderStorefrontL10n.text("provider_companies_search_placeholder"),
                    text: $store.searchQuery
                )
                .font(.custom("Beiruti-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel(
                    PPProviderStorefrontL10n.text("provider_companies_search_placeholder")
                )

                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        PPProviderStorefrontL10n.text("marketplace_category_clear")
                    )
                }
            }
            .padding(.horizontal, PPSpace.base)
            .frame(minHeight: 46)
            .background(Color.ppSurface, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        Color.ppPrimary.opacity(store.searchQuery.isEmpty ? 0.16 : 0.44),
                        lineWidth: contrast == .increased ? 1.4 : 0.9
                    )
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.04), radius: 8, y: 3)
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.top, PPSpace.base)
        .padding(.bottom, PPSpace.xs)
        .background(Color.ppBackground)
    }

    private var discoveryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PPSpace.sm) {
                ForEach(PPProviderCompaniesStore.DiscoveryMode.allCases) { mode in
                    let isSelected = store.discoveryMode == mode
                    Button {
                        if !reduceMotion {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        store.discoveryMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.symbolName)
                                .font(.system(size: 11, weight: .bold))
                            Text(PPProviderStorefrontL10n.text(mode.titleKey))
                                .font(.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .foregroundStyle(isSelected ? Color.white : Color.ppTextPrimary)
                        .background(
                            isSelected ? Color.ppPrimary : Color.ppSurface,
                            in: Capsule(style: .continuous)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(
                                    isSelected ? Color.clear : Color.ppSurfaceBorder.opacity(0.8),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: isSelected ? Color.ppPrimary.opacity(0.24) : Color.clear, radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, PPSpace.xxs)
        }
    }

    private var layoutToggle: some View {
        Button {
            store.prefersCompactLayout.toggle()
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        } label: {
            Image(
                systemName: store.prefersCompactLayout
                    ? "square.grid.2x2.fill"
                    : "rectangle.grid.1x2.fill"
            )
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 42, height: 42)
            .foregroundStyle(store.prefersCompactLayout ? Color.ppPrimary : Color.ppTextSecondary)
            .background(
                store.prefersCompactLayout ? Color.ppPrimary.opacity(0.14) : Color.ppSurface,
                in: Circle()
            )
            .overlay {
                Circle().stroke(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            PPProviderStorefrontL10n.text(
                store.prefersCompactLayout
                    ? "provider_companies_layout_toggle_grid"
                    : "provider_companies_layout_toggle_list"
            )
        )
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            PPProviderCompaniesStateView(
                symbol: "shippingbox",
                title: PPProviderStorefrontL10n.text("provider_companies_loading_title"),
                subtitle: PPProviderStorefrontL10n.text("provider_companies_loading_subtitle"),
                isLoading: true,
                retry: nil
            )
        case .failed:
            PPProviderCompaniesStateView(
                symbol: "wifi.exclamationmark",
                title: PPProviderStorefrontL10n.text("provider_companies_error_title"),
                subtitle: PPProviderStorefrontL10n.text("provider_companies_error_subtitle"),
                isLoading: false,
                retry: store.retry
            )
        case .empty:
            PPProviderCompaniesStateView(
                symbol: store.isPharmacy ? "cross.case" : "shippingbox",
                title: PPProviderStorefrontL10n.text(
                    store.isPharmacy
                        ? "provider_companies_empty_title_pharmacy"
                        : "provider_companies_empty_title_marketplace"
                ),
                subtitle: PPProviderStorefrontL10n.text(
                    store.isPharmacy
                        ? "provider_companies_empty_subtitle_pharmacy"
                        : "provider_companies_empty_subtitle_marketplace"
                ),
                isLoading: false,
                retry: nil
            )
        case .loaded:
            if store.visibleRecords.isEmpty {
                PPProviderCompaniesStateView(
                    symbol: store.hasActiveFilter ? "magnifyingglass" : "checkmark.seal",
                    title: PPProviderStorefrontL10n.text(
                        store.hasActiveFilter
                            ? "provider_companies_no_results_title"
                            : "provider_companies_no_featured_title"
                    ),
                    subtitle: PPProviderStorefrontL10n.text(
                        store.hasActiveFilter
                            ? "provider_companies_no_results_subtitle"
                            : "provider_companies_no_featured_subtitle"
                    ),
                    isLoading: false,
                    retry: nil
                )
            } else {
                LazyVStack(spacing: PPSpace.md) {
                    ForEach(store.visibleRecords, id: \.ownerID) { record in
                        PPProviderCompanySwiftUICard(
                            record: record,
                            isCompact: store.prefersCompactLayout,
                            isFavorite: store.isFavorite(record.ownerID),
                            onFavorite: {
                                store.toggleFavorite(for: record.ownerID)
                            },
                            onOpen: {
                                onOpenStorefront(record)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - State View

private struct PPProviderCompaniesStateView: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isLoading: Bool
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.12))
                    .frame(width: 68, height: 68)

                if isLoading {
                    ProgressView()
                        .tint(Color.ppPrimary)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.ppPrimary)
                }
            }

            VStack(spacing: PPSpace.xxs) {
                Text(title)
                    .font(.custom("Beiruti-Bold", size: 18, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retry = retry {
                Button(PPProviderStorefrontL10n.text("provider_retry"), action: retry)
                    .font(.custom("Beiruti-Bold", size: 14, relativeTo: .headline))
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ppPrimary)
            }
        }
        .padding(PPSpace.xl)
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reimagined Flagship Provider Card

private struct PPProviderCompanySwiftUICard: View {
    let record: PPProviderStorefrontProviderRecord
    let isCompact: Bool
    let isFavorite: Bool
    let onFavorite: () -> Void
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if isCompact {
                compactCard
            } else {
                showcaseCard
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            onOpen()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAction {
            onOpen()
        }
        .accessibilityAction(named: Text(accessibilityFavoriteActionTitle)) {
            onFavorite()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityFavoriteState)
        .accessibilityHint(PPProviderStorefrontL10n.text("a11y_cell_tap_hint"))
        .accessibilityIdentifier("providerCompanyCard_\(record.ownerID)")
    }

    // MARK: Showcase Flagship Card
    private var showcaseCard: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        return VStack(spacing: 0) {
            // 1. Cinematic Media Chamber
            showcaseCover

            // 2. Profile Details & Overlapping Avatar
            VStack(alignment: .leading, spacing: 0) {
                showcaseIdentity
                    .padding(.horizontal, PPSpace.base)
                    .padding(.top, 10)
                    .padding(.bottom, PPSpace.md)

                // 3. Floating Glass Bento Metric Ledger
                showcaseMetricLedger
                    .padding(.horizontal, PPSpace.md)
                    .padding(.bottom, PPSpace.md)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface, in: shape)
        .clipShape(shape)
        .overlay {
            shape.stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
        .shadow(color: cardShadowColor, radius: 18, y: 7)
    }

    // MARK: Cover Chamber
    private var showcaseCover: some View {
        ZStack {
            mediaFallback

            if hasCoverImage {
                providerRemoteImage(urlString: record.coverURLString)
            }
        }
        .frame(height: usesAccessibilityLayout ? 160 : 190)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            providerCategoryBadge
                .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            favoriteButton(isOverlayed: true)
                .padding(14)
        }
        .overlay(alignment: .bottomLeading) {
            if record.active {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.ppSuccess)
                        .frame(width: 7, height: 7)
                    Text(PPProviderStorefrontL10n.text("provider_company_status_active"))
                        .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.6)
                }
                .padding(PPSpace.md)
            }
        }
    }

    // MARK: Category Pill
    private var providerCategoryBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: storefrontSymbol)
                .font(.system(size: 11, weight: .bold))
            Text(categoryTitle)
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            Color.black.opacity(0.45),
            in: Capsule(style: .continuous)
        )
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 0.8)
        }
    }

    // MARK: Identity Block
    @ViewBuilder
    private var showcaseIdentity: some View {
        HStack(alignment: .top, spacing: 14) {
            providerAvatar(size: 64)
                .offset(y: -24)
                .padding(.bottom, -24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 5) {
                    Text(record.displayName)
                        .font(.custom("Beiruti-Bold", size: 20, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)

                    if record.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.ppSuccess)
                    }
                }

                Text(providerSummaryText)
                    .font(.custom("Beiruti-Regular", size: 13.5, relativeTo: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Reimagined Floating Bento Metric Ledger
    @ViewBuilder
    private var showcaseMetricLedger: some View {
        HStack(spacing: PPSpace.sm) {
            // Inventory Count Pill
            HStack(spacing: 6) {
                Image(systemName: isMedicineProvider ? "cross.vial.fill" : "shippingbox.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isMedicineProvider ? Color.ppPrimary : Color.ppAccent)

                Text(itemCountText)
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                (isMedicineProvider ? Color.ppPrimary : Color.ppAccent).opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            // Rating Pill
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppPremiumAccent)

                Text(ratingText)
                    .font(.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(
                Color.ppPremiumAccent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            // City Pill
            if !record.cityText.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ppTextSecondary)

                    Text(record.cityText)
                        .font(.custom("Beiruti-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
            }

            Spacer(minLength: 0)

            // Quick Storefront Arrow
            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.ppTextSecondary.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(Color.ppSecondarySurface, in: Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, PPSpace.xs)
        .frame(maxWidth: .infinity)
        .background(
            Color.ppSecondarySurface.opacity(reduceTransparency ? 1 : 0.85),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(0.7), lineWidth: 0.6)
        }
    }

    // MARK: Compact Card
    private var compactCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return HStack(alignment: .center, spacing: PPSpace.md) {
            compactStorefrontArtwork(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 4) {
                    Text(record.displayName)
                        .font(.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)

                    if record.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.ppSuccess)
                    }
                }

                Text(providerSummaryText)
                    .font(.custom("Beiruti-Regular", size: 12.5, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)

                HStack(spacing: PPSpace.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: isMedicineProvider ? "cross.case.fill" : "shippingbox.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.ppPrimary)
                        Text(itemCountText)
                            .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                            .foregroundStyle(Color.ppPrimary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.ppPremiumAccent)
                        Text(ratingText)
                            .font(.custom("Beiruti-Bold", size: 11.5, relativeTo: .caption))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            favoriteButton(isOverlayed: false)
        }
        .padding(PPSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface, in: shape)
        .overlay {
            shape.stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
        .shadow(color: cardShadowColor.opacity(0.6), radius: 10, y: 4)
    }

    private func compactStorefrontArtwork(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            mediaFallback

            if hasCompactArtwork {
                providerRemoteImage(
                    urlString: compactArtworkURL,
                    displaySize: CGSize(width: width, height: height)
                )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 0.8)
        }
    }

    // MARK: Avatar
    private func providerAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.ppSecondarySurface)

            if providerInitial.isEmpty {
                Image(systemName: storefrontSymbol)
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            } else {
                Text(providerInitial)
                    .font(.custom("Beiruti-Bold", size: size * 0.40, relativeTo: .headline))
                    .foregroundStyle(Color.ppPrimary)
            }

            if hasAvatarImage {
                providerRemoteImage(
                    urlString: record.avatarURLString,
                    displaySize: CGSize(width: size, height: size)
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.ppSurface, lineWidth: 3.5)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 6, y: 3)
    }

    private func providerRemoteImage(urlString: String, displaySize: CGSize? = nil) -> some View {
        AppRemoteImage(
            urlString: urlString,
            displaySize: displaySize,
            contentMode: .fill,
            showsRetryAction: false,
            placeholder: { Color.clear },
            failurePlaceholder: { Color.clear }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var mediaFallback: some View {
        ZStack {
            Color.ppSecondarySurface
            Image(systemName: storefrontSymbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.ppPrimary.opacity(0.6))
        }
    }

    // MARK: Favorite Button
    private func favoriteButton(isOverlayed: Bool) -> some View {
        let foreground: Color = isOverlayed
            ? (isFavorite ? Color.red : Color.white)
            : (isFavorite ? Color.red : Color.ppTextSecondary)

        let background: Color = isOverlayed
            ? Color.black.opacity(0.40)
            : (isFavorite ? Color.red.opacity(0.12) : Color.ppSecondarySurface)

        return Button {
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            onFavorite()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 38, height: 38)
                .background(background, in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().stroke(
                        isOverlayed ? Color.white.opacity(0.30) : cardBorderColor,
                        lineWidth: 0.8
                    )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPProviderStorefrontL10n.text("favorite"))
    }

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var hasCoverImage: Bool {
        !record.coverURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasAvatarImage: Bool {
        !record.avatarURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var compactArtworkURL: String {
        hasCoverImage ? record.coverURLString : record.avatarURLString
    }

    private var hasCompactArtwork: Bool {
        hasCoverImage || hasAvatarImage
    }

    private var providerInitial: String {
        let name = record.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstCharacter = name.first else { return "" }
        return String(firstCharacter).uppercased()
    }

    private var providerSummaryText: String {
        if !record.aboutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return record.aboutText
        }
        return PPProviderStorefrontL10n.text(
            isMedicineProvider
                ? "provider_companies_cell_subtitle_pharmacy"
                : "provider_companies_cell_subtitle_marketplace"
        )
    }

    private var isMedicineProvider: Bool {
        record.items.first?.isPetMedicine == true
    }

    private var storefrontSymbol: String {
        isMedicineProvider ? "cross.case.fill" : "storefront.fill"
    }

    private var cardBorderColor: Color {
        contrast == .increased
            ? Color.ppTextPrimary.opacity(0.46)
            : Color.ppSurfaceBorder.opacity(colorScheme == .dark ? 0.92 : 0.78)
    }

    private var cardBorderWidth: CGFloat {
        contrast == .increased ? 1.4 : 0.8
    }

    private var cardShadowColor: Color {
        guard contrast != .increased else { return .clear }
        return Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08)
    }

    private var categoryTitle: String {
        PPProviderStorefrontL10n.text(
            isMedicineProvider
                ? "provider_pharmacies_title"
                : "provider_marketplace_title"
        )
    }

    private var itemCountText: String {
        PPProviderStorefrontL10n.format(
            isMedicineProvider
                ? "provider_storefront_items_count_pharmacy_format"
                : "provider_storefront_items_count_marketplace_format",
            record.productCount
        )
    }

    private var ratingText: String {
        guard record.reviewCount > 0, record.ratingValue > 0 else {
            return PPProviderStorefrontL10n.text("provider_rating_new")
        }
        return String(
            format: "%.1f",
            locale: Locale(identifier: Language.currentLanguageCode() ?? "ar"),
            arguments: [record.ratingValue]
        )
    }

    private var accessibilityFavoriteActionTitle: String {
        PPProviderStorefrontL10n.text(
            isFavorite ? "a11y_btn_unfavorite" : "a11y_btn_favorite"
        )
    }

    private var accessibilityFavoriteState: String {
        PPProviderStorefrontL10n.text(
            isFavorite
                ? "adopt_detail_favorite_saved"
                : "adopt_detail_favorite_unsaved"
        )
    }

    private var accessibilityLabel: String {
        var components = [record.displayName]
        if record.verified {
            components.append(PPProviderStorefrontL10n.text("verified"))
        }
        if record.active {
            components.append(
                PPProviderStorefrontL10n.text("provider_company_status_active")
            )
        }
        components.append(itemCountText)
        if !record.cityText.isEmpty {
            components.append(record.cityText)
        }
        components.append(ratingAccessibilityText)
        return components
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var ratingAccessibilityText: String {
        guard record.reviewCount > 0, record.ratingValue > 0 else {
            return PPProviderStorefrontL10n.text("provider_rating_no_reviews")
        }
        return PPProviderStorefrontL10n.format(
            "provider_rating_accessibility_format",
            record.ratingValue,
            record.reviewCount
        )
    }
}

// MARK: - View Controller Wrapper

@MainActor
@objc(ProviderCompaniesListVC)
public final class PPProviderCompaniesViewController: UIViewController {
    @objc public var selectedProviderCategoryIdentifier = "marketplace" {
        didSet { configureStoreAndReloadIfNeeded() }
    }

    @objc public var selectedProviderCategoryTitleKey: String? {
        didSet { configureStoreAndReloadIfNeeded() }
    }

    @objc public var selectedProviderCategorySubtitleKey: String? {
        didSet { configureStoreAndReloadIfNeeded() }
    }

    private let store = PPProviderCompaniesStore()
    private var hostingController: UIHostingController<AnyView>?
    private var inheritedNavigationBarHidden: Bool?
    private var inheritedInteractivePopGestureEnabled: Bool?

    public init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ProviderCompaniesListVC is code-only.")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.ppBackground
        navigationItem.largeTitleDisplayMode = .never
        configureStoreAndReloadIfNeeded()

        let host = UIHostingController(rootView: rootView())
        hostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController {
            if inheritedNavigationBarHidden == nil {
                inheritedNavigationBarHidden = navigationController.isNavigationBarHidden
            }
            navigationController.setNavigationBarHidden(true, animated: animated)
        }
        if let gesture = navigationController?.interactivePopGestureRecognizer {
            if inheritedInteractivePopGestureEnabled == nil {
                inheritedInteractivePopGestureEnabled = gesture.isEnabled
            }
            gesture.isEnabled = true
        }
        navigationItem.title = store.categoryTitle
        hostingController?.rootView = rootView()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let gesture = navigationController?.interactivePopGestureRecognizer,
           let inheritedInteractivePopGestureEnabled {
            gesture.isEnabled = inheritedInteractivePopGestureEnabled
            self.inheritedInteractivePopGestureEnabled = nil
        }
        if let navigationController,
           let inheritedNavigationBarHidden {
            navigationController.setNavigationBarHidden(inheritedNavigationBarHidden, animated: animated)
            self.inheritedNavigationBarHidden = nil
        }
    }

    @objc(pp_preferredBottomSurfaceKind)
    public func ppPreferredBottomSurfaceKind() -> Int {
        0
    }

    private func configureStoreAndReloadIfNeeded() {
        store.configure(
            categoryIdentifier: selectedProviderCategoryIdentifier,
            categoryTitleKey: selectedProviderCategoryTitleKey,
            categorySubtitleKey: selectedProviderCategorySubtitleKey
        )
        navigationItem.title = store.categoryTitle
        guard isViewLoaded else { return }
        store.load()
    }

    private func rootView() -> AnyView {
        let languageCode = Language.currentLanguageCode() ?? "ar"
        return AnyView(
            PPProviderCompaniesScreen(
                store: store,
                onOpenStorefront: { [weak self] record in
                    self?.openStorefront(record)
                },
                onDismiss: { [weak self] in
                    self?.handleBackAction()
                }
            )
            .environment(\.locale, Locale(identifier: languageCode))
            .environment(
                \.layoutDirection,
                languageCode == "ar" ? .rightToLeft : .leftToRight
            )
        )
    }

    private func handleBackAction() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func openStorefront(_ record: PPProviderStorefrontProviderRecord) {
        let controller = PPProviderStorefrontProductsViewController(
            seller: record.user,
            items: record.items as NSArray,
            categoryIdentifier: store.categoryIdentifier
        )
        controller.parentVC = self
        navigationController?.pushViewController(controller, animated: true)
    }
}
