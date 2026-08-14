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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

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
    }

    private var showcaseCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                PPProviderStorefrontRemoteImage(
                    url: record.coverURLString,
                    placeholder: nil,
                    contentMode: .scaleAspectFill
                )
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .background(Color.ppPrimary.opacity(0.12))
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                HStack(spacing: PPSpace.sm) {
                    providerCategoryBadge
                    Spacer(minLength: 0)
                    favoriteButton
                }
                .padding(PPSpace.base)
            }
            .overlay(alignment: .bottomLeading) {
                identityBlock(foreground: .white)
                    .padding(PPSpace.base)
            }

            metrics
                .padding(PPSpace.base)
                .background(Color.ppSurface)
        }
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.74), lineWidth: contrast == .increased ? 1.2 : 0.8)
        }
        .shadow(color: Color.black.opacity(reduceMotion ? 0.04 : 0.08), radius: 16, y: 7)
    }

    private var compactCard: some View {
        HStack(spacing: PPSpace.base) {
            PPProviderStorefrontRemoteImage(
                url: record.avatarURLString,
                placeholder: nil,
                contentMode: .scaleAspectFill
            )
            .frame(width: 56, height: 56)
            .background(Color.ppSecondarySurface)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.ppSurfaceBorder, lineWidth: 0.8) }

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                HStack(spacing: PPSpace.xxs) {
                    Text(record.displayName)
                        .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
                        .foregroundStyle(Color.ppTextPrimary)
                        .lineLimit(1)
                    if record.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.ppSuccess)
                            .accessibilityHidden(true)
                    }
                }
                Text(record.aboutText.isEmpty ? categoryTitle : record.aboutText)
                    .font(.custom("Beiruti-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineLimit(1)
                compactMetadata
            }
            Spacer(minLength: 0)
            favoriteButton
        }
        .padding(PPSpace.base)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .stroke(Color.ppSurfaceBorder.opacity(contrast == .increased ? 1 : 0.74), lineWidth: contrast == .increased ? 1.2 : 0.8)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }

    private func identityBlock(foreground: Color) -> some View {
        HStack(alignment: .bottom, spacing: PPSpace.sm) {
            PPProviderStorefrontRemoteImage(
                url: record.avatarURLString,
                placeholder: nil,
                contentMode: .scaleAspectFill
            )
            .frame(width: 52, height: 52)
            .background(Color.ppSurface)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.white.opacity(0.84), lineWidth: 2) }

            VStack(alignment: .leading, spacing: PPSpace.xxs) {
                HStack(spacing: PPSpace.xxs) {
                    Text(record.displayName)
                        .font(.custom("Beiruti-Bold", size: 19, relativeTo: .headline))
                        .foregroundStyle(foreground)
                        .lineLimit(1)
                    if record.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.ppSuccess)
                            .accessibilityHidden(true)
                    }
                    if record.active {
                        Circle()
                            .fill(Color.ppSuccess)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }
                if !record.aboutText.isEmpty {
                    Text(record.aboutText)
                        .font(.custom("Beiruti-Regular", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(foreground.opacity(0.84))
                        .lineLimit(1)
                }
            }
        }
    }

    private var providerCategoryBadge: some View {
        Text(categoryTitle)
            .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
            .foregroundStyle(Color.white)
            .padding(.horizontal, PPSpace.sm)
            .frame(minHeight: 28)
            .background(Color.black.opacity(0.28), in: Capsule(style: .continuous))
    }

    private var metrics: some View {
        HStack(spacing: PPSpace.sm) {
            metric(symbol: "shippingbox.fill", text: itemCountText, tint: Color.ppPrimary)
            if !record.cityText.isEmpty {
                metric(symbol: "mappin.and.ellipse", text: record.cityText, tint: Color.ppTextSecondary)
            }
            Spacer(minLength: 0)
            metric(symbol: "star.fill", text: ratingText, tint: Color.ppPremiumAccent)
        }
    }

    private var compactMetadata: some View {
        HStack(spacing: PPSpace.sm) {
            Text(itemCountText)
            if !record.cityText.isEmpty {
                Text(record.cityText)
            }
            Text(ratingText)
        }
        .font(.custom("Beiruti-Regular", size: 12, relativeTo: .caption))
        .foregroundStyle(Color.ppTextSecondary)
        .lineLimit(1)
    }

    private func metric(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: PPSpace.xxs) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.custom("Beiruti-Bold", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, PPSpace.sm)
        .frame(minHeight: 30)
        .background(tint.opacity(0.10), in: Capsule(style: .continuous))
    }

    private var favoriteButton: some View {
        Button(action: onFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.ppPrimary : Color.white)
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.24), in: Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.20), lineWidth: 0.8) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PPProviderStorefrontL10n.text("favorite"))
        .accessibilityAddTraits(isFavorite ? .isSelected : [])
    }

    private var categoryTitle: String {
        let medicine = record.items.first?.isPetMedicine == true
        return PPProviderStorefrontL10n.text(
            medicine ? "provider_pharmacies_title" : "provider_marketplace_title"
        )
    }

    private var itemCountText: String {
        let medicine = record.items.first?.isPetMedicine == true
        return PPProviderStorefrontL10n.format(
            medicine
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
        [record.displayName, itemCountText, record.cityText, ratingText]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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
