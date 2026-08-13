import CoreLocation
import Foundation
import UIKit

enum HomeScreenPhase: Equatable {
    case coldLoading
    case warmLoading
    case loaded
    case refreshing
    case partial
    case empty
    case failed(message: String)

    var isLoading: Bool {
        switch self {
        case .coldLoading, .warmLoading, .refreshing:
            return true
        default:
            return false
        }
    }
}

enum HomeConnectivityState: Equatable {
    case online
    case offline
}

enum HomeLocationPresentation: Equatable {
    case notDetermined
    case loading
    case ready
    case denied
    case restricted
    case failed
}

struct HomeLocationModel: Equatable {
    var presentation: HomeLocationPresentation = .notDetermined
    var areaName = ""
    var latitude: CLLocationDegrees?
    var longitude: CLLocationDegrees?
    var isManual = false

    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }
}

enum HomeHeroKind {
    case pet
    case reminder
    case promotion
    case marketplace
    case petOnboarding
    case pharmacy
}

enum HomeHeroAction {
    case openPetProfiles
    case editPet(NSObject)
    case openPromotion(NSObject, interaction: String)
    case openMarketplace(NSObject?)
    case openPharmacy(NSObject?)
}

/// Live, category-scoped facts surfaced by the marketplace hero compass.
/// These cases describe read-only public inventory; navigation remains owned
/// by the hero's existing primary and secondary actions.
enum HomeMarketplaceSignalKind: CaseIterable, Hashable {
    case marketplace
    case services
    case advertisements
}

enum HomeMarketplaceSignalValue: Equatable {
    case idle
    case loading
    case available(Int)
    case failed
}

struct HomeMarketplaceSignals: Equatable {
    var categoryID: Int?
    var marketplace: HomeMarketplaceSignalValue
    var services: HomeMarketplaceSignalValue
    var advertisements: HomeMarketplaceSignalValue

    init(
        categoryID: Int? = nil,
        marketplace: HomeMarketplaceSignalValue = .idle,
        services: HomeMarketplaceSignalValue = .idle,
        advertisements: HomeMarketplaceSignalValue = .idle
    ) {
        self.categoryID = categoryID
        self.marketplace = marketplace
        self.services = services
        self.advertisements = advertisements
    }

    func value(
        for kind: HomeMarketplaceSignalKind
    ) -> HomeMarketplaceSignalValue {
        switch kind {
        case .marketplace:
            return marketplace
        case .services:
            return services
        case .advertisements:
            return advertisements
        }
    }

    mutating func set(
        _ value: HomeMarketplaceSignalValue,
        for kind: HomeMarketplaceSignalKind
    ) {
        switch kind {
        case .marketplace:
            marketplace = value
        case .services:
            services = value
        case .advertisements:
            advertisements = value
        }
    }
}

struct HomeHeroPage: Identifiable {
    let id: String
    let kind: HomeHeroKind
    let eyebrow: String
    let title: String
    let subtitle: String
    let primaryTitle: String
    let secondaryTitle: String?
    let imageURL: String?
    let localImage: UIImage?
    let accentHex: String
    let action: HomeHeroAction
    let autoScrollInterval: TimeInterval

    init(
        id: String,
        kind: HomeHeroKind,
        eyebrow: String,
        title: String,
        subtitle: String,
        primaryTitle: String,
        secondaryTitle: String?,
        imageURL: String?,
        localImage: UIImage?,
        accentHex: String,
        action: HomeHeroAction,
        autoScrollInterval: TimeInterval = 4.8
    ) {
        self.id = id
        self.kind = kind
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.imageURL = imageURL
        self.localImage = localImage
        self.accentHex = accentHex
        self.action = action
        self.autoScrollInterval = autoScrollInterval
    }
}

struct HomePetModel: Identifiable {
    let id: String
    let name: String
    let breedOrCategory: String
    let age: String
    let imageURL: String?
    let categoryID: Int
    let isDefault: Bool
    let raw: NSObject
}

struct HomeCategoryModel: Identifiable {
    let id: String
    let title: String
    let imageURL: String?
    let localImage: UIImage?
    let accent: UIColor
    let raw: NSObject
}

enum HomePriorityDestination {
    case shop
    case advertisements
    case veterinary
    case pharmacy
    case services
    case petProfile
}

struct HomePriorityAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: UIColor
    let destination: HomePriorityDestination
}

enum HomeCardKind {
    case accessory
    case food
    case advertisement
    case service
    case buyAgain
}

struct HomeCardModel: Identifiable {
    let id: String
    let kind: HomeCardKind
    let context: PPCellContext
    let viewModel: PPUniversalCellViewModel
}

struct HomeOrderModel: Identifiable {
    let id: String
    let reference: String
    let statusKey: String
    let statusTitle: String
    let statusHint: String
    let symbol: String
    let progress: Double
    let itemCount: Int
    let amount: String
    let previewImageURLs: [String]
    let raw: NSObject
}

enum HomeSectionID: String, Hashable {
    case currentOrder
    case buyAgain
    case recommendations
    case accessories
    case advertisements
    case food
    case nearbyAdvertisements
    case services
}

enum HomeSectionRenderState {
    case loading
    case content([HomeCardModel])
    case empty(title: String, message: String, actionTitle: String?)
    case failed(title: String, message: String, retryTitle: String)
}

struct HomeSectionModel: Identifiable {
    let id: Int
    let kind: HomeSectionID
    let title: String
    let subtitle: String?
    let seeAllTitle: String?
    let rawConfigSectionID: Int
    let state: HomeSectionRenderState
}

struct HomeConfigSection: Identifiable {
    let id: Int
    let type: String
    let isVisible: Bool
    let metadata: [AnyHashable: Any]
}

struct HomeConfigModel {
    var sections: [HomeConfigSection]
    var titleViewMode: String
    var premiumCareVisible: Bool
    var novaFloatingVisible: Bool
    var backgroundGlowsFaded: Bool
    var pureLensVisible: Bool
    var cameFromCache: Bool

    var orderedSectionIDs: [Int] {
        sections.map(\.id)
    }

    var visibleSectionIDs: Set<Int> {
        Set(sections.lazy.filter(\.isVisible).map(\.id))
    }

    static let fallback = HomeConfigModel(
        sections: [
            HomeConfigSection(id: 20, type: "PPHomeSectionPureLens", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 15, type: "PPHomeSectionPremiumSearch", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 17, type: "PPHomeSectionMarketplaceHero", isVisible: false, metadata: [:]),
            HomeConfigSection(id: 16, type: "PPHomeSectionProviderCategoryNav", isVisible: false, metadata: [:]),
            HomeConfigSection(id: 0, type: "PPHomeSectionHero", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 5, type: "PPHomeSectionMainKinds", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 9, type: "PPHomeSectionPremiumCare", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 1, type: "PPHomeSectionQuickActions", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 2, type: "PPHomeSectionCurrentOrders", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 7, type: "PPHomeSectionAccessories", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 18, type: "PPHomeSectionSuggestionAds", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 19, type: "PPHomeSectionSuggestionAccessories", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 6, type: "PPHomeSectionSuggestions", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 4, type: "PPHomeSectionCarousel", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 10, type: "PPHomeSectionLastFood", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 12, type: "PPHomeSectionAdsNearBy", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 11, type: "PPHomeSectionNearbyServices", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 13, type: "PPHomeSectionAdopt", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 14, type: "PPHomeSectionBuyAgain", isVisible: true, metadata: [:]),
            HomeConfigSection(id: 8, type: "PPHomeSectionPetProfile", isVisible: true, metadata: [:]),
        ],
        titleViewMode: "location",
        premiumCareVisible: true,
        novaFloatingVisible: true,
        backgroundGlowsFaded: false,
        pureLensVisible: true,
        cameFromCache: false
    )

    func isVisible(_ rawSectionID: Int) -> Bool {
        visibleSectionIDs.contains(rawSectionID)
    }

    func section(withID rawSectionID: Int) -> HomeConfigSection? {
        sections.first { $0.id == rawSectionID }
    }
}

struct HomeViewState {
    var phase: HomeScreenPhase
    var connectivity: HomeConnectivityState
    var languageCode: String
    var isRightToLeft: Bool
    var cartCount: Int
    var selectedMainKindID: Int?
    var marketplaceSignals: HomeMarketplaceSignals
    var selectedPetID: String?
    var location: HomeLocationModel
    var config: HomeConfigModel
    var heroPages: [HomeHeroPage]
    var promotionPages: [HomeHeroPage]
    var marketplaceHeroPage: HomeHeroPage?
    var selectedHeroIndex: Int
    var pets: [HomePetModel]
    var categories: [HomeCategoryModel]
    var priorityActions: [HomePriorityAction]
    var featuredOrder: HomeOrderModel?
    var sections: [HomeSectionModel]
    var hasStaleContent: Bool
    var bottomContentClearance: CGFloat

    static let initial = HomeViewState(
        phase: .coldLoading,
        connectivity: .online,
        languageCode: "ar",
        isRightToLeft: true,
        cartCount: 0,
        selectedMainKindID: nil,
        marketplaceSignals: HomeMarketplaceSignals(),
        selectedPetID: nil,
        location: HomeLocationModel(),
        config: .fallback,
        heroPages: [],
        promotionPages: [],
        marketplaceHeroPage: nil,
        selectedHeroIndex: 0,
        pets: [],
        categories: [],
        priorityActions: [],
        featuredOrder: nil,
        sections: [],
        hasStaleContent: false,
        bottomContentClearance: 8
    )
}
