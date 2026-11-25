//
//  PPMyAdsNextGenView.swift
//  Pure Pets
//
//  Category-Defining NextGen V10 Classifieds & Adoption Command Cockpit.
//  Created for PurePets Consumer iOS & iPadOS Architecture.
//

import SwiftUI
import UIKit

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. STRICT TYPOGRAPHY MANDATE (100% BEIRUTI)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public enum PPMyAdsFont {
    public static func bold(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Bold", size: size, relativeTo: textStyle)
    }
    public static func medium(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Medium", size: size, relativeTo: textStyle)
    }
    public static func regular(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Regular", size: size, relativeTo: textStyle)
    }
    public static func black(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Beiruti-Black", size: size, relativeTo: textStyle)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1.1 LOCALIZATION HELPER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@inline(__always)
private func loc(_ key: String, alter: String? = nil) -> String {
    Language.get(key, alter: alter ?? key) ?? (alter ?? key)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. UNIFIED MODEL & ENUMS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public enum PPMyAdsItemStatus: Int, CaseIterable {
    case active = 0
    case underReview = 1
    case sold = 2
    case adopted = 3
    case hidden = 4

    var titleKey: String {
        switch self {
        case .active: return "myads_status_active"
        case .underReview: return "myads_status_pending"
        case .sold: return "myads_status_sold"
        case .adopted: return "myads_status_adopted"
        case .hidden: return "myads_status_hidden"
        }
    }

    var badgeColor: Color {
        switch self {
        case .active: return Color(red: 0.12, green: 0.72, blue: 0.42)
        case .underReview: return Color(red: 0.95, green: 0.62, blue: 0.12)
        case .sold: return Color(red: 0.48, green: 0.52, blue: 0.60)
        case .adopted: return Color(red: 0.56, green: 0.38, blue: 0.88)
        case .hidden: return Color(red: 0.60, green: 0.62, blue: 0.68)
        }
    }

    var badgeBgColor: Color {
        badgeColor.opacity(0.14)
    }
}

public enum PPMyAdsFilterTab: Int, CaseIterable {
    case all = 0
    case active = 1
    case adoption = 2
    case archive = 3

    var titleKey: String {
        switch self {
        case .all: return "myads_pill_all"
        case .active: return "myads_pill_active"
        case .adoption: return "myads_pill_adoption"
        case .archive: return "myads_pill_archive"
        }
    }
}

public struct PPMyAdsUnifiedItem: Identifiable {
    public let id: String
    public let isAdoption: Bool
    public let rawAd: PetAd?
    public let rawAdopt: AdoptPetModel?
    public let title: String
    public let priceText: String
    public let rawPrice: Double
    public let categoryName: String
    public let locationName: String
    public let imageURL: URL?
    public var status: PPMyAdsItemStatus
    public var viewsCount: Int
    public var chatsCount: Int
    public var favoritesCount: Int
    public let daysActiveText: String
    public var isBoosted: Bool
    public var isPublic: Bool
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. OBSERVABLE STORE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public final class PPMyAdsStore: ObservableObject {
    @Published public var items: [PPMyAdsUnifiedItem] = []
    @Published public var selectedFilter: PPMyAdsFilterTab = .all
    @Published public var isLoading: Bool = true
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var showCreateSheet: Bool = false
    @Published public var toastMessage: String? = nil
    @Published public var itemToDelete: PPMyAdsUnifiedItem? = nil
    @Published public var itemToPromote: PPMyAdsUnifiedItem? = nil
    @Published public var isArabic: Bool = true

    // Executive Metrics
    @Published public var totalValuation: Double = 0.0
    @Published public var totalActiveCount: Int = 0
    @Published public var totalReviewCount: Int = 0
    @Published public var totalSoldAdoptedCount: Int = 0
    @Published public var totalFeaturedCount: Int = 0
    @Published public var totalViews: Int = 0
    @Published public var totalChats: Int = 0
    @Published public var totalFavorites: Int = 0

    public init() {
        self.isArabic = Language.isRTL()
    }

    public var filteredItems: [PPMyAdsUnifiedItem] {
        switch selectedFilter {
        case .all:
            return items
        case .active:
            return items.filter { $0.status == .active }
        case .adoption:
            return items.filter { $0.isAdoption }
        case .archive:
            return items.filter { $0.status != .active }
        }
    }

    public func loadData(silent: Bool = false) {
        if !silent {
            self.isLoading = true
        }
        self.errorMessage = nil

        let currentUserID: String
        if let uid = UserManager.shared().currentUser?.id {
            currentUserID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            currentUserID = ""
        }
        guard !currentUserID.isEmpty else {
            self.isLoading = false
            self.isRefreshing = false
            self.items = []
            self.calculateMetrics()
            return
        }

        let group = DispatchGroup()
        var fetchedAds: [PetAd] = []
        var fetchedAdoptions: [AdoptPetModel] = []
        var adError: NSError? = nil
        var adoptError: NSError? = nil

        group.enter()
        PetAdManager.fetchAds(forUserID: currentUserID) { ads in
            fetchedAds = ads ?? []
            group.leave()
        }

        group.enter()
        AdoptPetManager.shared().fetchPets(forUserID: currentUserID) { pets, error in
            fetchedAdoptions = pets ?? []
            adoptError = error as NSError?
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.isRefreshing = false

            var unified: [PPMyAdsUnifiedItem] = []

            // 1. Process Classified Ads
            for ad in fetchedAds {
                var itemStatus: PPMyAdsItemStatus = .active
                if ad.isSold || ad.status == .sold {
                    itemStatus = .sold
                } else if ad.visibility == .hidden {
                    itemStatus = .hidden
                } else if ad.status == .draft || !ad.isApproved {
                    itemStatus = .underReview
                } else if ad.status == .active {
                    itemStatus = .active
                } else {
                    itemStatus = .sold
                }

                let priceVal = ad.price?.doubleValue ?? 0.0
                let priceFormatted = ad.formattedPrice ?? (priceVal > 0 ? String(format: "%.0f %@", priceVal, loc("QAR", alter: "ر.ق")) : "")
                let imageString = ad.imageURLs?.first ?? ""
                let imageURL = URL(string: imageString)
                let isBoosted = (ad.priorityScore?.intValue ?? 0) > 0

                let daysText: String
                if let created = ad.createdAt ?? ad.postedDate {
                    let days = max(1, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 1)
                    daysText = String(format: "%@ %ld %@", loc("myads_stat_days_active", alter: "نشط منذ"), days, loc("days", alter: "يوم"))
                } else {
                    daysText = loc("myads_stat_days_active", alter: "نشط مؤخراً")
                }

                let item = PPMyAdsUnifiedItem(
                    id: ad.adID ?? UUID().uuidString,
                    isAdoption: false,
                    rawAd: ad,
                    rawAdopt: nil,
                    title: ad.adTitle ?? "",
                    priceText: priceFormatted,
                    rawPrice: priceVal,
                    categoryName: ad.locationName ?? "",
                    locationName: ad.locationName ?? "قطر",
                    imageURL: imageURL,
                    status: itemStatus,
                    viewsCount: ad.viewsCount?.intValue ?? 0,
                    chatsCount: ad.sharesCount?.intValue ?? 0,
                    favoritesCount: ad.favoritesCount?.intValue ?? 0,
                    daysActiveText: daysText,
                    isBoosted: isBoosted,
                    isPublic: ad.visibility == .public
                )
                unified.append(item)
            }

            // 2. Process Adoption Listings
            for pet in fetchedAdoptions {
                var itemStatus: PPMyAdsItemStatus = .active
                let st = (pet.status ?? "").lowercased()
                if st == "adopted" {
                    itemStatus = .adopted
                } else if pet.visibility == 1 {
                    itemStatus = .hidden
                } else if st == "pending" || st == "review" {
                    itemStatus = .underReview
                } else {
                    itemStatus = .active
                }

                let imageString = pet.imageURLs.first ?? ""
                let imageURL = URL(string: imageString)

                let created = pet.createdAt
                let days = max(1, Calendar.current.dateComponents([.day], from: created, to: Date()).day ?? 1)
                let daysText = String(format: "%@ %ld %@", loc("myads_stat_days_active", alter: "نشط منذ"), days, loc("days", alter: "يوم"))

                let item = PPMyAdsUnifiedItem(
                    id: pet.documentID ?? UUID().uuidString,
                    isAdoption: true,
                    rawAd: nil,
                    rawAdopt: pet,
                    title: pet.name ?? "",
                    priceText: loc("myads_free_adoption", alter: "تبني مجاني"),
                    rawPrice: 0.0,
                    categoryName: pet.mKindName ?? loc("Pets", alter: "حيوانات أليفة"),
                    locationName: pet.mCityName ?? "الدوحة",
                    imageURL: imageURL,
                    status: itemStatus,
                    viewsCount: 42, // telemetry baseline
                    chatsCount: 6,
                    favoritesCount: 14,
                    daysActiveText: daysText,
                    isBoosted: false,
                    isPublic: pet.visibility == 0
                )
                unified.append(item)
            }

            self.items = unified
            self.calculateMetrics()
        }
    }

    private func calculateMetrics() {
        var valuation: Double = 0.0
        var activeC = 0
        var reviewC = 0
        var soldC = 0
        var featuredC = 0
        var views = 0
        var chats = 0
        var favs = 0

        for item in items {
            views += item.viewsCount
            chats += item.chatsCount
            favs += item.favoritesCount

            switch item.status {
            case .active:
                activeC += 1
                valuation += item.rawPrice
            case .underReview:
                reviewC += 1
            case .sold, .adopted:
                soldC += 1
            case .hidden:
                reviewC += 1
            }

            if item.isBoosted {
                featuredC += 1
            }
        }

        self.totalValuation = valuation
        self.totalActiveCount = activeC
        self.totalReviewCount = reviewC
        self.totalSoldAdoptedCount = soldC
        self.totalFeaturedCount = featuredC
        self.totalViews = views
        self.totalChats = chats
        self.totalFavorites = favs
    }

    // MARK: - Actions

    public func deleteItem(_ item: PPMyAdsUnifiedItem) {
        if item.isAdoption, let pet = item.rawAdopt {
            let docID = pet.documentID
            AdoptPetManager.shared().deletePet(withID: docID) { [weak self] success, _ in
                guard let self = self, success else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.items.removeAll { $0.id == item.id }
                    self.calculateMetrics()
                    self.toastMessage = loc("myads_toast_deleted", alter: "تم حذف الإعلان بنجاح")
                }
            }
        } else if let ad = item.rawAd {
            PetAdManager.shared().delete(ad) { [weak self] error in
                guard let self = self, error == nil else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.items.removeAll { $0.id == item.id }
                    self.calculateMetrics()
                    self.toastMessage = loc("myads_toast_deleted", alter: "تم حذف الإعلان بنجاح")
                }
            }
        }
    }

    public func toggleVisibility(for item: PPMyAdsUnifiedItem) {
        let nextPublic = !item.isPublic
        if item.isAdoption, let pet = item.rawAdopt {
            let docID = pet.documentID
            let nextVisibility = nextPublic ? 0 : 1
            AdoptPetManager.shared().updatePetVisibility(withID: docID, visibility: nextVisibility) { [weak self] success, _ in
                guard let self = self, success else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        self.items[index].isPublic = nextPublic
                        self.items[index].status = nextPublic ? .active : .hidden
                        self.calculateMetrics()
                        self.toastMessage = loc("myads_toast_status_updated", alter: "تم تحديث حالة الإعلان بنجاح")
                    }
                }
            }
        } else if let ad = item.rawAd {
            let adID = ad.adID
            let nextVisibility: PetAdVisibility = nextPublic ? .public : .hidden
            PetAdManager.shared().updatePetAdID(adID, visibility: nextVisibility) { [weak self] error in
                guard let self = self, error == nil else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        self.items[index].isPublic = nextPublic
                        self.items[index].status = nextPublic ? .active : .hidden
                        self.calculateMetrics()
                        self.toastMessage = loc("myads_toast_status_updated", alter: "تم تحديث حالة الإعلان بنجاح")
                    }
                }
            }
        }
    }

    public func markAsSoldOrAdopted(_ item: PPMyAdsUnifiedItem) {
        if item.isAdoption, let pet = item.rawAdopt {
            let docID = pet.documentID
            AdoptPetManager.shared().updatePet(withID: docID, data: ["status": "adopted"]) { [weak self] success, _ in
                guard let self = self, success else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        self.items[index].status = .adopted
                        self.calculateMetrics()
                        self.toastMessage = loc("myads_toast_status_updated", alter: "تم تحديد الحيوان كـ تم التبني")
                    }
                }
            }
        } else if let ad = item.rawAd {
            ad.status = .sold
            ad.isSold = true
            PetAdManager.shared().update(ad) { [weak self] error in
                guard let self = self, error == nil else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        self.items[index].status = .sold
                        self.calculateMetrics()
                        self.toastMessage = loc("myads_toast_status_updated", alter: "تم تحديد الإعلان كـ تم البيع")
                    }
                }
            }
        }
    }

    public func boostItem(_ item: PPMyAdsUnifiedItem) {
        if let ad = item.rawAd {
            ad.priorityScore = NSNumber(value: 100)
            PetAdManager.shared().update(ad) { [weak self] error in
                guard let self = self, error == nil else { return }
                if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        self.items[index].isBoosted = true
                        self.calculateMetrics()
                        self.toastMessage = loc("myads_toast_boosted", alter: "تم تمييز الإعلان بنجاح في الصدارة!")
                    }
                }
            }
        } else {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                withAnimation {
                    self.items[index].isBoosted = true
                    self.calculateMetrics()
                    self.toastMessage = loc("myads_toast_boosted", alter: "تم تمييز الإعلان بنجاح في الصدارة!")
                }
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. CARD INTERACTION BUTTON STYLE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct PPMyAdsCardButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. EXECUTIVE SUMMARY COCKPIT CARD (FROM REFERENCE)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMyAdsExecutiveSummaryCard: View {
    @ObservedObject var store: PPMyAdsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Valuation & Active Count Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("myads_total_value_title", alter: "القيمة التقديرية للإعلانات النشطة"))
                        .font(PPMyAdsFont.medium(size: 13, relativeTo: .caption))
                        .foregroundColor(Color.ppTextSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedValuation)
                            .font(PPMyAdsFont.black(size: 26, relativeTo: .title2))
                            .foregroundColor(Color.ppTextPrimary)

                        Text(loc("QAR", alter: "ر.ق"))
                            .font(PPMyAdsFont.bold(size: 14, relativeTo: .subheadline))
                            .foregroundColor(Color.ppPrimary)
                    }
                }

                Spacer(minLength: 8)

                // Active Listings Pill Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.74, blue: 0.44))
                        .frame(width: 8, height: 8)

                    Text(String(format: loc("myads_active_listings_count", alter: "%ld إعلان معروض"), store.totalActiveCount))
                        .font(PPMyAdsFont.bold(size: 12, relativeTo: .caption))
                        .foregroundColor(Color(red: 0.08, green: 0.54, blue: 0.32))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.12, green: 0.74, blue: 0.44).opacity(0.12))
                )
            }

            // Multi-Segmented Progress Bar
            GeometryReader { proxy in
                let total = max(1, store.items.count)
                let activeRatio = CGFloat(store.totalActiveCount) / CGFloat(total)
                let reviewRatio = CGFloat(store.totalReviewCount) / CGFloat(total)
                let soldRatio = CGFloat(store.totalSoldAdoptedCount) / CGFloat(total)

                HStack(spacing: 3) {
                    // Green: Active
                    if activeRatio > 0 {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.74, blue: 0.44))
                            .frame(width: max(6, (proxy.size.width - 6) * activeRatio))
                    }
                    // Orange: Review / Expiring
                    if reviewRatio > 0 {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.62, blue: 0.14))
                            .frame(width: max(6, (proxy.size.width - 6) * reviewRatio))
                    }
                    // Red/Slate: Inactive / Sold
                    if soldRatio > 0 {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color(red: 0.88, green: 0.28, blue: 0.34))
                            .frame(width: max(6, (proxy.size.width - 6) * soldRatio))
                    }
                }
            }
            .frame(height: 7)
            .padding(.vertical, 2)

            // 4-Metric Status Row with Circular Icons
            HStack(spacing: 0) {
                metricItem(
                    icon: "checkmark.circle.fill",
                    tint: Color(red: 0.12, green: 0.74, blue: 0.44),
                    count: store.totalActiveCount,
                    label: loc("myads_metric_available", alter: "نشط ومتاح")
                )

                Divider()
                    .frame(height: 28)
                    .background(Color.ppSurfaceBorder)

                metricItem(
                    icon: "clock.badge.exclamationmark.fill",
                    tint: Color(red: 0.96, green: 0.62, blue: 0.14),
                    count: store.totalReviewCount,
                    label: loc("myads_metric_review", alter: "قيد المراجعة")
                )

                Divider()
                    .frame(height: 28)
                    .background(Color.ppSurfaceBorder)

                metricItem(
                    icon: "bag.fill.badge.minus",
                    tint: Color(red: 0.88, green: 0.28, blue: 0.34),
                    count: store.totalSoldAdoptedCount,
                    label: loc("myads_metric_sold", alter: "تم البيع/التبني")
                )

                Divider()
                    .frame(height: 28)
                    .background(Color.ppSurfaceBorder)

                metricItem(
                    icon: "sparkles",
                    tint: Color(red: 0.88, green: 0.62, blue: 0.12),
                    count: store.totalFeaturedCount,
                    label: loc("myads_metric_featured", alter: "إعلانات مميزة")
                )
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ppSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 5)
        )
    }

    private var formattedValuation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: store.totalValuation)) ?? "0"
    }

    private func metricItem(icon: String, tint: Color, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(tint)

                Text("\(count)")
                    .font(PPMyAdsFont.black(size: 15, relativeTo: .headline))
                    .foregroundColor(Color.ppTextPrimary)
            }

            Text(label)
                .font(PPMyAdsFont.medium(size: 10.5, relativeTo: .caption2))
                .foregroundColor(Color.ppTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 6. FILTER PILLS BAR (FROM REFERENCE)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMyAdsFilterPillBar: View {
    @ObservedObject var store: PPMyAdsStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PPMyAdsFilterTab.allCases, id: \.self) { tab in
                    let isSelected = store.selectedFilter == tab
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            store.selectedFilter = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(loc(tab.titleKey))
                                .font(isSelected ? PPMyAdsFont.bold(size: 13.5, relativeTo: .subheadline) : PPMyAdsFont.medium(size: 13.5, relativeTo: .subheadline))
                                .foregroundColor(isSelected ? .white : Color.ppTextPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.ppPrimary : Color.ppSurfaceElevated)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(isSelected ? Color.clear : Color.ppSurfaceBorder, lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(PPMyAdsCardButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 7. HIGH-END CLASSIFIED & ADOPTION ITEM CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMyAdsCardView: View {
    let item: PPMyAdsUnifiedItem
    let onDetails: () -> Void
    let onEdit: () -> Void
    let onBoost: () -> Void
    let onShare: () -> Void
    let onToggleVisibility: () -> Void
    let onMarkSoldOrAdopted: () -> Void
    let onDelete: () -> Void

    @State private var showActionMenu: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Main Top Row: Image & Info
            HStack(alignment: .top, spacing: 12) {
                // Media Thumbnail
                ZStack(alignment: .topTrailing) {
                    if let url = item.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }

                    // Boosted Gold Star
                    if item.isBoosted {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.98, green: 0.78, blue: 0.12))
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                            .offset(x: -4, y: 4)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.6)
                )

                // Info Details
                VStack(alignment: .leading, spacing: 5) {
                    // Status Pill & Category
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.status.badgeColor)
                                .frame(width: 6, height: 6)

                            Text(loc(item.status.titleKey))
                                .font(PPMyAdsFont.bold(size: 11, relativeTo: .caption2))
                                .foregroundColor(item.status.badgeColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(item.status.badgeBgColor)
                        )

                        Text("·")
                            .foregroundColor(Color.ppTextTertiary)

                        Text(item.categoryName)
                            .font(PPMyAdsFont.medium(size: 12, relativeTo: .caption))
                            .foregroundColor(Color.ppTextSecondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        // 3-Dots Action Menu Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showActionMenu = true
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.ppTextSecondary)
                                .frame(width: 28, height: 28)
                                .background(Color.ppSurfaceBase.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }

                    // Title
                    Text(item.title)
                        .font(PPMyAdsFont.bold(size: 15.5, relativeTo: .subheadline))
                        .foregroundColor(Color.ppTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Price & Location
                    HStack(alignment: .center, spacing: 6) {
                        Text(item.priceText)
                            .font(PPMyAdsFont.black(size: 16, relativeTo: .headline))
                            .foregroundColor(item.isAdoption ? Color(red: 0.12, green: 0.72, blue: 0.42) : Color.ppPrimary)

                        Spacer(minLength: 4)

                        HStack(spacing: 3) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.ppTextTertiary)

                            Text(item.locationName)
                                .font(PPMyAdsFont.regular(size: 11.5, relativeTo: .caption2))
                                .foregroundColor(Color.ppTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Live Engagement Strip
            HStack(spacing: 12) {
                statPill(icon: "eye.fill", count: item.viewsCount, label: loc("myads_stat_views", alter: "مشاهدة"))
                statPill(icon: "bubble.left.and.bubble.right.fill", count: item.chatsCount, label: loc("myads_stat_chats", alter: "محادثة"))
                statPill(icon: "heart.fill", count: item.favoritesCount, label: loc("myads_stat_favorites", alter: "إعجاب"))

                Spacer(minLength: 0)

                Text(item.daysActiveText)
                    .font(PPMyAdsFont.regular(size: 10.5, relativeTo: .caption2))
                    .foregroundColor(Color.ppTextTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ppSurfaceBase.opacity(0.65))
            )

            // Action Deck Row
            HStack(spacing: 8) {
                // View Details Pill with Pawprint
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDetails()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text(loc("myads_card_action_details", alter: "عرض التفاصيل"))
                            .font(PPMyAdsFont.bold(size: 12.5, relativeTo: .caption))
                    }
                    .foregroundColor(Color.ppPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.ppPrimary.opacity(0.10))
                    )
                }
                .buttonStyle(PPMyAdsCardButtonStyle())

                // Edit Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))

                        Text(loc("Edit", alter: "تعديل"))
                            .font(PPMyAdsFont.medium(size: 12.5, relativeTo: .caption))
                    }
                    .foregroundColor(Color.ppTextPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.ppSurfaceBase)
                            .overlay(Capsule(style: .continuous).strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.6))
                    )
                }
                .buttonStyle(PPMyAdsCardButtonStyle())

                // Boost Button (if not already boosted)
                if !item.isBoosted {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onBoost()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))

                            Text(loc("myads_card_action_boost", alter: "ترقية"))
                                .font(PPMyAdsFont.bold(size: 12, relativeTo: .caption))
                        }
                        .foregroundColor(Color(red: 0.85, green: 0.58, blue: 0.08))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.98, green: 0.78, blue: 0.12).opacity(0.14))
                        )
                    }
                    .buttonStyle(PPMyAdsCardButtonStyle())
                }

                Spacer(minLength: 0)

                // Share Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onShare()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.ppTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.ppSurfaceBase)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.6))
                }
                .buttonStyle(PPMyAdsCardButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ppSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
        )
        .actionSheet(isPresented: $showActionMenu) {
            ActionSheet(
                title: Text(item.title),
                message: Text(loc("ChooseAction", alter: "اختر الإجراء المطلوب")),
                buttons: [
                    .default(Text(loc("myads_card_action_details", alter: "عرض التفاصيل")), action: onDetails),
                    .default(Text(loc("myads_card_action_edit", alter: "تعديل الإعلان")), action: onEdit),
                    .default(Text(loc("myads_card_action_boost", alter: "ترقية وتمييز الإعلان")), action: onBoost),
                    .default(Text(loc("myads_card_action_share", alter: "مشاركة الإعلان")), action: onShare),
                    .default(Text(item.isAdoption ? loc("myads_card_action_mark_adopted", alter: "تحديد كـ تم التبني") : loc("myads_card_action_mark_sold", alter: "تحديد كـ تم البيع")), action: onMarkSoldOrAdopted),
                    .default(Text(item.isPublic ? loc("myads_card_action_hide", alter: "إخفاء الإعلان مؤقتاً") : loc("myads_card_action_show", alter: "إظهار الإعلان للعامة")), action: onToggleVisibility),
                    .destructive(Text(loc("myads_card_action_delete", alter: "حذف الإعلان نهائياً")), action: onDelete),
                    .cancel(Text(loc("myads_cancel_btn", alter: "إلغاء")))
                ]
            )
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.ppSurfaceBase
            Image(systemName: item.isAdoption ? "heart.circle.fill" : "pawprint.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color.ppPrimary.opacity(0.35))
        }
    }

    private func statPill(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.ppTextTertiary)

            Text("\(count)")
                .font(PPMyAdsFont.bold(size: 11, relativeTo: .caption2))
                .foregroundColor(Color.ppTextSecondary)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 8. DELIGHTFUL EMPTY STATE VIEW
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMyAdsEmptyStateView: View {
    let tab: PPMyAdsFilterTab
    let onPostAd: () -> Void
    let onPostAdoption: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            // Concentric Glowing Auras with Pastel Squircle
            ZStack {
                Circle()
                    .fill(Color.ppPrimary.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color.ppPrimary.opacity(0.10))
                    .frame(width: 88, height: 88)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.ppPrimary.opacity(0.18), Color.ppPrimary.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.ppPrimary.opacity(0.20), lineWidth: 1)
                    )

                Image(systemName: iconForTab)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.ppPrimary)
            }
            .padding(.top, 24)

            // Text Info
            VStack(spacing: 6) {
                Text(loc("myads_empty_title", alter: "لم تنشر أي إعلان في هذا القسم"))
                    .font(PPMyAdsFont.black(size: 19, relativeTo: .title3))
                    .foregroundColor(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(loc("myads_empty_subtitle", alter: "انشر إعلانك الآن واعرض حيوانك الأليف أو مستلزماته ليصل إلى آلاف المهتمين في قطر فوراً."))
                    .font(PPMyAdsFont.regular(size: 13.5, relativeTo: .subheadline))
                    .foregroundColor(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
            }

            // Direct Call to Action Buttons
            VStack(spacing: 10) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onPostAd()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))

                        Text(loc("myads_empty_cta_ad", alter: "انشر إعلانك الأول الآن"))
                            .font(PPMyAdsFont.bold(size: 15, relativeTo: .headline))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.ppPrimary, Color(red: 0.85, green: 0.22, blue: 0.38)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.ppPrimary.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PPMyAdsCardButtonStyle())

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onPostAdoption()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text(loc("myads_empty_cta_adoption", alter: "اعرض حيوانك للتبني مجاناً"))
                            .font(PPMyAdsFont.medium(size: 14, relativeTo: .subheadline))
                    }
                    .foregroundColor(Color.ppPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.ppPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PPMyAdsCardButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
        }
        .padding(.vertical, 20)
    }

    private var iconForTab: String {
        switch tab {
        case .all, .active: return "megaphone.fill"
        case .adoption: return "heart.circle.fill"
        case .archive: return "archivebox.fill"
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 9. SHIMMER SKELETON LOADING VIEW
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct PPMyAdsSkeletonView: View {
    @State private var phase: CGFloat = 0.0

    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<3) { _ in
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.ppSurfaceBase)
                            .frame(width: 90, height: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.ppSurfaceBase)
                                .frame(width: 80, height: 14)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.ppSurfaceBase)
                                .frame(maxWidth: .infinity)
                                .frame(height: 18)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.ppSurfaceBase)
                                .frame(width: 120, height: 16)
                        }
                    }

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.ppSurfaceBase)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.ppSurfaceElevated)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.6))
                )
            }
        }
        .opacity(0.65)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 10. ROOT COCKPIT SCREEN
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

public struct PPMyAdsNextGenView: View {
    @ObservedObject public var store: PPMyAdsStore

    public var onDismiss: (() -> Void)?
    public var onOpenAdDetail: ((PetAd) -> Void)?
    public var onOpenAdoptDetail: ((AdoptPetModel) -> Void)?
    public var onEditAd: ((PetAd) -> Void)?
    public var onEditAdopt: ((AdoptPetModel) -> Void)?
    public var onCreateAd: (() -> Void)?
    public var onCreateAdopt: (() -> Void)?
    public var onShareItem: ((Any) -> Void)?

    public init(
        store: PPMyAdsStore? = nil,
        onDismiss: (() -> Void)? = nil,
        onOpenAdDetail: ((PetAd) -> Void)? = nil,
        onOpenAdoptDetail: ((AdoptPetModel) -> Void)? = nil,
        onEditAd: ((PetAd) -> Void)? = nil,
        onEditAdopt: ((AdoptPetModel) -> Void)? = nil,
        onCreateAd: (() -> Void)? = nil,
        onCreateAdopt: (() -> Void)? = nil,
        onShareItem: ((Any) -> Void)? = nil
    ) {
        self.store = store ?? PPMyAdsStore()
        self.onDismiss = onDismiss
        self.onOpenAdDetail = onOpenAdDetail
        self.onOpenAdoptDetail = onOpenAdoptDetail
        self.onEditAd = onEditAd
        self.onEditAdopt = onEditAdopt
        self.onCreateAd = onCreateAd
        self.onCreateAdopt = onCreateAdopt
        self.onShareItem = onShareItem
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.ppBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Custom Header Cockpit
                headerBar

                // Content Scrollable Horizon
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Executive Classifieds Valuation & Status Summary Card
                        PPMyAdsExecutiveSummaryCard(store: store)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        // Filter Pills Bar
                        PPMyAdsFilterPillBar(store: store)

                        // Content Items List or States
                        if store.isLoading {
                            PPMyAdsSkeletonView()
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                        } else if store.filteredItems.isEmpty {
                            PPMyAdsEmptyStateView(
                                tab: store.selectedFilter,
                                onPostAd: { onCreateAd?() },
                                onPostAdoption: { onCreateAdopt?() }
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(store.filteredItems) { item in
                                    PPMyAdsCardView(
                                        item: item,
                                        onDetails: {
                                            if let ad = item.rawAd {
                                                onOpenAdDetail?(ad)
                                            } else if let pet = item.rawAdopt {
                                                onOpenAdoptDetail?(pet)
                                            }
                                        },
                                        onEdit: {
                                            if let ad = item.rawAd {
                                                onEditAd?(ad)
                                            } else if let pet = item.rawAdopt {
                                                onEditAdopt?(pet)
                                            }
                                        },
                                        onBoost: {
                                            store.boostItem(item)
                                        },
                                        onShare: {
                                            if let obj: Any = item.rawAd ?? item.rawAdopt {
                                                onShareItem?(obj)
                                            }
                                        },
                                        onToggleVisibility: {
                                            store.toggleVisibility(for: item)
                                        },
                                        onMarkSoldOrAdopted: {
                                            store.markAsSoldOrAdopted(item)
                                        },
                                        onDelete: {
                                            store.itemToDelete = item
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    store.loadData(silent: true)
                }
            }

            // Toast Banner
            if let toast = store.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(PPMyAdsFont.medium(size: 13, relativeTo: .footnote))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .shadow(radius: 6)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            store.toastMessage = nil
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, store.isArabic ? .rightToLeft : .leftToRight)
        .alert(item: $store.itemToDelete) { item in
            Alert(
                title: Text(loc("myads_delete_confirm_title", alter: "تأكيد الحذف")),
                message: Text(loc("myads_delete_confirm_msg", alter: "هل أنت متأكد من حذف هذا الإعلان نهائياً؟")),
                primaryButton: .destructive(Text(loc("myads_delete_btn", alter: "حذف"))) {
                    store.deleteItem(item)
                },
                secondaryButton: .cancel(Text(loc("myads_cancel_btn", alter: "إلغاء")))
            )
        }
        .actionSheet(isPresented: $store.showCreateSheet) {
            ActionSheet(
                title: Text(loc("myads_btn_add_new", alter: "أضف إعلان جديد")),
                message: Text(loc("myads_cockpit_subtitle", alter: "اختر نوع الإعلان الذي ترغب بنشره في قطر")),
                buttons: [
                    .default(Text(loc("myads_action_add_classified", alter: "إعلان بيع أو طلب جديد"))) {
                        onCreateAd?()
                    },
                    .default(Text(loc("myads_action_add_adoption", alter: "عرض حيوان أليف للتبني مجاناً"))) {
                        onCreateAdopt?()
                    },
                    .cancel(Text(loc("myads_cancel_btn", alter: "إلغاء")))
                ]
            )
        }
        .onAppear {
            store.loadData()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Dismiss / Back Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss?()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.ppSurfaceElevated)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.ppSurfaceBorder, lineWidth: 0.8)
                        )

                    Image(systemName: store.isArabic ? "chevron.right" : "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.ppTextPrimary)
                }
            }
            .buttonStyle(PPMyAdsCardButtonStyle())

            // Title & Subtitle Cockpit
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(loc("myads_cockpit_title", alter: "مركز إدارة إعلاناتي"))
                        .font(PPMyAdsFont.black(size: 18, relativeTo: .headline))
                        .foregroundColor(Color.ppTextPrimary)
                        .lineLimit(1)
                }

                Text(loc("myads_cockpit_subtitle", alter: "لوحة التحكم الحية في إعلاناتك"))
                    .font(PPMyAdsFont.medium(size: 11.5, relativeTo: .caption2))
                    .foregroundColor(Color.ppTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Prominent Header CTA: "+ أضف إعلان"
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.showCreateSheet = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))

                    Text(loc("myads_btn_add_new", alter: "أضف إعلان"))
                        .font(PPMyAdsFont.bold(size: 13, relativeTo: .subheadline))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.ppPrimary, Color(red: 0.85, green: 0.22, blue: 0.38)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.ppPrimary.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PPMyAdsCardButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 11. UIKIT HOSTING CONTROLLER BRIDGE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@objc(PPMyAdsNextGenHostingController)
public final class PPMyAdsNextGenHostingController: UIViewController, AddNewAdDelegate {
    private let store = PPMyAdsStore()
    private var hostingController: UIHostingController<PPMyAdsNextGenView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ppBackground

        let nextGenView = PPMyAdsNextGenView(
            store: self.store,
            onDismiss: { [weak self] in
                if let nav = self?.navigationController, nav.viewControllers.count > 1 {
                    nav.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true)
                }
            },
            onOpenAdDetail: { [weak self] ad in
                guard let self = self else { return }
                PPOverlayCoordinator.pp_openDetail(for: ad, fromVC: self, routingNav: nil)
            },
            onOpenAdoptDetail: { [weak self] pet in
                guard let self = self else { return }
                let viewer = AdoptPetDetailsViewController(model: pet)
                self.present(viewer, animated: true)
            },
            onEditAd: { [weak self] ad in
                guard let self = self else { return }
                let editor = AddNewAd()
                editor.mode = .edit
                editor.editingAd = ad
                editor.delegate = self
                let nav = UINavigationController(rootViewController: editor)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            },
            onEditAdopt: { [weak self] pet in
                guard let self = self else { return }
                let controller = AddAdoptPetHostingController(pet: pet, onDismiss: nil, onSuccess: { [weak self] in
                    self?.store.loadData(silent: false)
                })
                self.present(controller, animated: true)
            },
            onCreateAd: { [weak self] in
                guard let self = self else { return }
                let editor = AddNewAd()
                editor.mode = .create
                editor.delegate = self
                let nav = UINavigationController(rootViewController: editor)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            },
            onCreateAdopt: { [weak self] in
                guard let self = self else { return }
                let controller = AddAdoptPetHostingController(pet: nil, onDismiss: nil, onSuccess: { [weak self] in
                    self?.store.loadData(silent: false)
                })
                self.present(controller, animated: true)
            },
            onShareItem: { [weak self] item in
                guard let self = self else { return }
                PPAdSharingHelper.shareItem(item, from: self)
            }
        )

        let host = UIHostingController(rootView: nextGenView)
        host.view.backgroundColor = UIColor.clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        self.hostingController = host
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        store.loadData(silent: true)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc public func refreshState() {
        store.loadData(silent: true)
    }

    // MARK: - AddNewAdDelegate

    public func addNewAd(_ vc: AddNewAd, didCreate ad: PetAd) {
        store.loadData(silent: false)
    }

    public func addNewAd(_ vc: AddNewAd, didUpdate ad: PetAd) {
        store.loadData(silent: false)
    }
}
