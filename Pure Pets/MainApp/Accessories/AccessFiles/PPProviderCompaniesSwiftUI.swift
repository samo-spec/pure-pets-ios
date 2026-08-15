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

struct PPProviderStorefrontRemoteImage: UIViewRepresentable {
    let url: String
    let placeholder: UIImage?
    let contentMode: UIView.ContentMode

    final class Coordinator {
        var loadedURL = ""
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = contentMode
        imageView.backgroundColor = .clear
        update(imageView, coordinator: context.coordinator)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.contentMode = contentMode
        update(imageView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: Coordinator) {
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
    }

    private func update(_ imageView: UIImageView, coordinator: Coordinator) {
        let safeURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard coordinator.loadedURL != safeURL else { return }

        coordinator.loadedURL = safeURL
        PPImageLoaderManager.shared().cancelImageLoad(for: imageView)
        imageView.image = placeholder
        guard !safeURL.isEmpty else { return }

        PPImageLoaderManager.shared().setImage(
            on: imageView,
            url: safeURL,
            placeholder: placeholder,
            transitionStyle: .crossDissolve,
            completion: nil
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
            case .topSellers: return "chart.bar.fill"
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

struct PPProviderCompaniesScreen: View {
    @ObservedObject var store: PPProviderCompaniesStore
    let onOpenStorefront: (PPProviderStorefrontProviderRecord) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 0) {
            discoveryHeader
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    hero
                    content
                }
                .padding(.horizontal, PPSpace.base)
                .padding(.vertical, PPSpace.lg)
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
                VStack(alignment: .leading, spacing: PPSpace.xxs) {
                    Text(store.categoryTitle)
                        .font(.custom("Beiruti-Bold", size: 24, relativeTo: .title2))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                    Text(store.categorySupportText)
                        .font(.custom("Beiruti-Regular", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: PPSpace.sm)
                layoutToggle
                discoveryMenu
            }

            HStack(spacing: PPSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.ppTextSecondary)
                    .accessibilityHidden(true)
                TextField(
                    PPProviderStorefrontL10n.text("provider_companies_search_placeholder"),
                    text: $store.searchQuery
                )
                .font(.custom("Beiruti-Regular", size: 15, relativeTo: .body))
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
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        PPProviderStorefrontL10n.text("marketplace_category_clear")
                    )
                }
            }
            .padding(.horizontal, PPSpace.base)
            .frame(minHeight: 48)
            .background(Color.ppSurface, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        Color.ppSurfaceBorder.opacity(
                            contrast == .increased ? 1 : 0.72
                        ),
                        lineWidth: contrast == .increased ? 1.2 : 0.8
                    )
            }
        }
        .padding(.horizontal, PPSpace.base)
        .padding(.top, PPSpace.base)
        .padding(.bottom, PPSpace.sm)
        .background(Color.ppBackground)
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
            .frame(width: 44, height: 44)
            .foregroundStyle(store.prefersCompactLayout ? Color.ppPrimary : Color.ppTextSecondary)
            .background(
                store.prefersCompactLayout ? Color.ppPrimary.opacity(0.12) : Color.ppSurface,
                in: Circle()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            PPProviderStorefrontL10n.text(
                store.prefersCompactLayout
                    ? "provider_companies_layout_toggle_grid"
                    : "provider_companies_layout_toggle_list"
            )
        )
        .accessibilityHint(PPProviderStorefrontL10n.text("provider_companies_layout_toggle_hint"))
    }

    private var discoveryMenu: some View {
        Menu {
            ForEach(PPProviderCompaniesStore.DiscoveryMode.allCases) { mode in
                Button {
                    store.discoveryMode = mode
                } label: {
                    Label(
                        PPProviderStorefrontL10n.text(mode.titleKey),
                        systemImage: mode.symbolName
                    )
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.ppTextSecondary)
                .background(Color.ppSurface, in: Circle())
        }
        .accessibilityLabel(PPProviderStorefrontL10n.text("provider_companies_discovery_title"))
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: PPSpace.base) {
            Image(systemName: store.isPharmacy ? "cross.case.fill" : "storefront.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 48, height: 48)
                .background(Color.ppPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                Text(
                    PPProviderStorefrontL10n.text(
                        store.isPharmacy
                            ? "provider_companies_hero_support_pharmacy"
                            : "provider_companies_hero_support_marketplace_short"
                    )
                )
                    .font(.custom("Beiruti-Bold", size: 16, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                Text(PPProviderStorefrontL10n.text(store.discoveryMode.titleKey))
                    .font(.custom("Beiruti-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(PPSpace.base)
        .background(Color.ppSecondarySurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(0.66), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
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
                LazyVStack(spacing: PPSpace.base) {
                    ForEach(store.visibleRecords, id: \.ownerID) { record in
                        PPProviderCompanySwiftUICard(
                            record: record,
                            isCompact: store.prefersCompactLayout,
                            isFavorite: store.isFavorite(record.ownerID),
                            onFavorite: { store.toggleFavorite(for: record.ownerID) },
                            onOpen: { onOpenStorefront(record) }
                        )
                        .id(record.ownerID + (store.prefersCompactLayout ? "-compact" : "-showcase"))
                    }
                }
            }
        }
    }
}

private struct PPProviderCompaniesStateView: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isLoading: Bool
    let retry: (() -> Void)?

    var body: some View {
        VStack(spacing: PPSpace.base) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.ppPrimary)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(Color.ppPrimary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.ppPrimary.opacity(0.10), in: Circle())
            Text(title)
                .font(.custom("Beiruti-Bold", size: 19, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button(PPProviderStorefrontL10n.text("provider_retry"), action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.ppPrimary)
            }
        }
        .padding(PPSpace.xl)
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PPProviderCompanySwiftUICard: View {
    let record: PPProviderStorefrontProviderRecord
    let isCompact: Bool
    let isFavorite: Bool
    let onFavorite: () -> Void
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
        .contentShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(PPProviderStorefrontL10n.text("a11y_cell_tap_hint"))
        .accessibilityAction {
            onOpen()
        }
        .accessibilityIdentifier("providerCompanyCard_\(record.ownerID)")
    }

    private var showcaseCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )

        VStack(spacing: 0) {
            showcaseCover

            showcaseIdentity
                .padding(.horizontal, PPSpace.base)
                .padding(.top, PPSpace.base)
                .padding(.bottom, PPSpace.md)

            Divider()
                .overlay(Color.ppSeparator)
                .padding(.horizontal, PPSpace.base)

            showcaseMetricLedger
                .padding(.horizontal, PPSpace.base)
                .padding(.vertical, PPSpace.md)
                .background(Color.ppWarmPorcelain.opacity(reduceTransparency ? 1 : 0.74))
        }
        .background(Color.ppSurface, in: shape)
        .clipShape(shape)
        .overlay {
            shape.stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
        .shadow(color: cardShadowColor, radius: 18, y: 8)
    }

    private var compactCard: some View {
        let shape = RoundedRectangle(
            cornerRadius: PPCorner.card,
            style: .continuous
        )

        Group {
            if usesAccessibilityLayout {
                compactAccessibilityContent
            } else {
                compactHorizontalContent
            }
        }
        .padding(PPSpace.base)
        .background(Color.ppSurface, in: shape)
        .overlay {
            shape.stroke(cardBorderColor, lineWidth: cardBorderWidth)
        }
        .shadow(color: cardShadowColor.opacity(0.72), radius: 12, y: 5)
    }

    private var showcaseCover: some View {
        ZStack {
            mediaFallback

            if hasCoverImage {
                PPProviderStorefrontRemoteImage(
                    url: record.coverURLString,
                    placeholder: nil,
                    contentMode: .scaleAspectFill
                )
                .accessibilityHidden(true)
            }
        }
        .frame(height: usesAccessibilityLayout ? 154 : 180)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay {
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.18)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            providerCategoryBadge
                .padding(PPSpace.md)
        }
        .overlay(alignment: .topTrailing) {
            favoriteButton(isOverlayed: true)
                .padding(PPSpace.md)
        }
    }

    private var providerCategoryBadge: some View {
        Label(categoryTitle, systemImage: storefrontSymbol)
            .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
            .foregroundStyle(Color.ppTextPrimary)
            .padding(.horizontal, PPSpace.md)
            .frame(minHeight: 32)
            .background(
                Color.ppSurface.opacity(reduceTransparency ? 1 : 0.94),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(cardBorderColor, lineWidth: contrast == .increased ? 1.2 : 0.6)
            }
    }

    @ViewBuilder
    private var showcaseIdentity: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                providerAvatar(size: 64)
                providerIdentity(
                    showsCategory: true,
                    nameLineLimit: 3,
                    summaryLineLimit: 5
                )
            }
        } else {
            HStack(alignment: .top, spacing: PPSpace.md) {
                providerAvatar(size: 62)
                providerIdentity(
                    showsCategory: false,
                    nameLineLimit: 2,
                    summaryLineLimit: 2
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var compactHorizontalContent: some View {
        HStack(alignment: .center, spacing: PPSpace.md) {
            compactStorefrontArtwork(width: 82, height: 82)

            VStack(alignment: .leading, spacing: PPSpace.xs) {
                providerIdentity(
                    showsCategory: true,
                    nameLineLimit: 2,
                    summaryLineLimit: 2
                )
                compactFacts
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            favoriteButton(isOverlayed: false)
        }
    }

    private var compactAccessibilityContent: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                compactStorefrontArtwork(width: 96, height: 82)
                Spacer(minLength: PPSpace.sm)
                favoriteButton(isOverlayed: false)
            }

            providerIdentity(
                showsCategory: true,
                nameLineLimit: 4,
                summaryLineLimit: 6
            )

            Divider()
                .overlay(Color.ppSeparator)

            compactFacts
        }
    }

    private func providerIdentity(
        showsCategory: Bool,
        nameLineLimit: Int,
        summaryLineLimit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            if showsCategory {
                Text(categoryTitle)
                    .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.ppPrimary)
            }

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.xs) {
                Text(record.displayName)
                    .font(.custom("Beiruti-Bold", size: 19, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineLimit(nameLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                if record.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ppSuccess)
                        .accessibilityHidden(true)
                }
            }

            if record.active {
                HStack(spacing: PPSpace.xs) {
                    Circle()
                        .fill(Color.ppSuccess)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(PPProviderStorefrontL10n.text("provider_company_status_active"))
                }
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.ppSuccess)
            }

            Text(providerSummaryText)
                .font(.custom("Beiruti-Regular", size: 14, relativeTo: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(summaryLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var showcaseMetricLedger: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                ledgerMetric(
                    symbol: "shippingbox.fill",
                    text: itemCountText,
                    tint: Color.ppPrimary
                )
                if !record.cityText.isEmpty {
                    ledgerMetric(
                        symbol: "mappin.and.ellipse",
                        text: record.cityText,
                        tint: Color.ppTextSecondary
                    )
                }
                ledgerMetric(
                    symbol: "star.fill",
                    text: ratingText,
                    tint: Color.ppPremiumAccent
                )
            }
        } else {
            HStack(spacing: 0) {
                ledgerMetric(
                    symbol: "shippingbox.fill",
                    text: itemCountText,
                    tint: Color.ppPrimary
                )

                if !record.cityText.isEmpty {
                    ledgerDivider
                    ledgerMetric(
                        symbol: "mappin.and.ellipse",
                        text: record.cityText,
                        tint: Color.ppTextSecondary
                    )
                }

                ledgerDivider
                ledgerMetric(
                    symbol: "star.fill",
                    text: ratingText,
                    tint: Color.ppPremiumAccent
                )
            }
        }
    }

    @ViewBuilder
    private var compactFacts: some View {
        if usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                compactFact(symbol: "shippingbox.fill", text: itemCountText)
                if !record.cityText.isEmpty {
                    compactFact(symbol: "mappin.and.ellipse", text: record.cityText)
                }
                compactFact(symbol: "star.fill", text: ratingText, tint: Color.ppPremiumAccent)
            }
        } else {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                HStack(spacing: PPSpace.md) {
                    compactFact(symbol: "shippingbox.fill", text: itemCountText)
                    compactFact(
                        symbol: "star.fill",
                        text: ratingText,
                        tint: Color.ppPremiumAccent
                    )
                }
                if !record.cityText.isEmpty {
                    compactFact(symbol: "mappin.and.ellipse", text: record.cityText)
                }
            }
            .lineLimit(1)
        }
    }

    private func ledgerMetric(
        symbol: String,
        text: String,
        tint: Color
    ) -> some View {
        HStack(spacing: PPSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))

            Text(text)
                .font(.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(usesAccessibilityLayout ? 3 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ledgerDivider: some View {
        Divider()
            .overlay(Color.ppSeparator)
            .frame(height: 34)
            .padding(.horizontal, PPSpace.sm)
    }

    private func compactFact(
        symbol: String,
        text: String,
        tint: Color = Color.ppTextSecondary
    ) -> some View {
        HStack(spacing: PPSpace.xs) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(usesAccessibilityLayout ? 3 : 1)
        }
    }

    private func compactStorefrontArtwork(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack {
            mediaFallback

            if hasCompactArtwork {
                PPProviderStorefrontRemoteImage(
                    url: compactArtworkURL,
                    placeholder: nil,
                    contentMode: .scaleAspectFill
                )
                .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .stroke(cardBorderColor, lineWidth: contrast == .increased ? 1.2 : 0.8)
        }
        .overlay(alignment: .bottomTrailing) {
            if hasCoverImage && hasAvatarImage {
                providerAvatar(size: 34)
                    .padding(PPSpace.xs)
            }
        }
        .accessibilityHidden(true)
    }

    private func providerAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.ppSoftRose)

            if providerInitial.isEmpty {
                Image(systemName: storefrontSymbol)
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(Color.ppPrimary)
            } else {
                Text(providerInitial)
                    .font(.custom("Beiruti-Bold", size: size * 0.38, relativeTo: .headline))
                    .foregroundStyle(Color.ppPrimary)
            }

            if hasAvatarImage {
                PPProviderStorefrontRemoteImage(
                    url: record.avatarURLString,
                    placeholder: nil,
                    contentMode: .scaleAspectFill
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    contrast == .increased
                        ? Color.ppTextPrimary.opacity(0.48)
                        : Color.ppSurface,
                    lineWidth: contrast == .increased ? 2 : 3
                )
        }
        .accessibilityHidden(true)
    }

    private var mediaFallback: some View {
        ZStack {
            Color.ppSecondarySurface
            Image(systemName: storefrontSymbol)
                .font(.system(size: usesAccessibilityLayout ? 34 : 30, weight: .semibold))
                .foregroundStyle(Color.ppPrimary.opacity(0.74))
        }
        .accessibilityHidden(true)
    }

    private func favoriteButton(isOverlayed: Bool) -> some View {
        let foreground: Color = {
            if isOverlayed { return Color.white }
            return isFavorite ? Color.ppPrimary : Color.ppTextSecondary
        }()
        let background: Color = {
            if isOverlayed {
                return Color.black.opacity(reduceTransparency ? 0.58 : 0.34)
            }
            return isFavorite ? Color.ppPrimary.opacity(0.12) : Color.ppSecondarySurface
        }()

        Button(action: onFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(background, in: Circle())
                .overlay {
                    Circle().stroke(
                        isOverlayed
                            ? Color.white.opacity(0.34)
                            : cardBorderColor,
                        lineWidth: contrast == .increased ? 1.2 : 0.8
                    )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPProviderStorefrontL10n.text("favorite"))
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
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
        return Color.black.opacity(colorScheme == .dark ? 0.20 : 0.07)
    }

    private var categoryTitle: String {
        return PPProviderStorefrontL10n.text(
            isMedicineProvider
                ? "provider_pharmacies_title"
                : "provider_marketplace_title"
        )
    }

    private var itemCountText: String {
        return PPProviderStorefrontL10n.format(
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
        return String(format: "%.1f", record.ratingValue)
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
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.title = store.categoryTitle
        hostingController?.rootView = rootView()
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
            PPProviderCompaniesScreen(store: store) { [weak self] record in
                self?.openStorefront(record)
            }
            .environment(\.locale, Locale(identifier: languageCode))
            .environment(
                \.layoutDirection,
                languageCode == "ar" ? .rightToLeft : .leftToRight
            )
        )
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
