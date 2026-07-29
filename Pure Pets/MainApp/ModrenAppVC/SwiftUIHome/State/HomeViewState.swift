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
}

enum HomeHeroAction {
    case openPetProfiles
    case editPet(NSObject)
    case openPromotion(NSObject, interaction: String)
    case openMarketplace(NSObject?)
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
    let id: HomeSectionID
    let title: String
    let subtitle: String?
    let seeAllTitle: String?
    let rawConfigSectionID: Int
    let state: HomeSectionRenderState
}

struct HomeConfigModel {
    var orderedSectionIDs: [Int]
    var visibleSectionIDs: Set<Int>
    var titleViewMode: String
    var premiumCareVisible: Bool
    var novaFloatingVisible: Bool
    var backgroundGlowsFaded: Bool
    var cameFromCache: Bool

    static let fallback = HomeConfigModel(
        orderedSectionIDs: [15, 17, 16, 0, 9, 1, 5, 2, 7, 18, 19, 6, 4, 10, 12, 8, 11, 13, 14],
        visibleSectionIDs: Set(0 ... 19),
        titleViewMode: "location",
        premiumCareVisible: true,
        novaFloatingVisible: true,
        backgroundGlowsFaded: false,
        cameFromCache: false
    )

    func isVisible(_ rawSectionID: Int) -> Bool {
        visibleSectionIDs.contains(rawSectionID)
    }
}

struct HomeViewState {
    var phase: HomeScreenPhase
    var connectivity: HomeConnectivityState
    var languageCode: String
    var isRightToLeft: Bool
    var cartCount: Int
    var selectedMainKindID: Int?
    var selectedPetID: String?
    var location: HomeLocationModel
    var config: HomeConfigModel
    var heroPages: [HomeHeroPage]
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
        selectedPetID: nil,
        location: HomeLocationModel(),
        config: .fallback,
        heroPages: [],
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
