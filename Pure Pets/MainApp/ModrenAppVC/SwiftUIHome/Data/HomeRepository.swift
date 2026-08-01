import CoreLocation
import Foundation
import Network

enum HomeRepositoryEvent {
    case mainKinds([NSObject])
    case promotions([NSObject])
    case accessories([PetAccessory])
    case food([PetAccessory])
    case advertisements([PetAd])
    case nearbyAdvertisements([PetAd], showingRecentFallback: Bool)
    case services([ServiceModel])
    case petProfiles([NSObject])
    case petReminders([NSObject])
    case orders([NSObject])
    case homeConfig(
        sections: [[AnyHashable: Any]],
        titleViewMode: String,
        premiumCareVisible: Bool,
        novaFloatingVisible: Bool,
        backgroundGlowsFaded: Bool,
        fromCache: Bool
    )
    case location(
        state: PPHomeBridgeLocationState,
        areaName: String,
        coordinate: CLLocationCoordinate2D?,
        manual: Bool
    )
    case connectivity(HomeConnectivityState)
    case failure(sourceRawValue: Int, error: Error)
}

@MainActor
final class HomeRepository {
    var onEvent: ((HomeRepositoryEvent) -> Void)?

    private let bridge: PPHomeDataBridge
    private var pathMonitor: NWPathMonitor?
    private let pathQueue = DispatchQueue(
        label: "com.purepets.home.network-path",
        qos: .utility
    )
    private var isStarted = false

    init(
        bridge: PPHomeDataBridge = PPHomeDataBridge(),
        pathMonitor: NWPathMonitor = NWPathMonitor()
    ) {
        self.bridge = bridge
        self.pathMonitor = pathMonitor
        bindBridge()
    }

    isolated deinit {
        pathMonitor?.cancel()
        bridge.stop()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let monitor = pathMonitor ?? NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.onEvent?(
                    .connectivity(path.status == .satisfied ? .online : .offline)
                )
            }
        }
        monitor.start(queue: pathQueue)
        bridge.start()
    }

    func refresh() {
        bridge.refresh()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        pathMonitor?.cancel()
        pathMonitor = nil
        bridge.stop()
    }

    func setManualLocation(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        title: String
    ) {
        bridge.setManualLocationLatitude(
            latitude,
            longitude: longitude,
            title: title
        )
    }

    func useAutomaticLocation() {
        bridge.useAutomaticLocation()
    }

    func requestLocationAuthorization() {
        bridge.requestLocationAuthorization()
    }

    func resolveAccessories(
        ids: [String],
        completion: @escaping ([PetAccessory]) -> Void
    ) {
        bridge.fetchAccessories(ids: ids, completion: completion)
    }

    func loadAccessories(
        mainCategoryID: Int,
        completion: @escaping ([PetAccessory]) -> Void
    ) {
        bridge.fetchAccessories(
            mainCategoryID: mainCategoryID,
            completion: completion
        )
    }

    private func bindBridge() {
        bridge.mainKindsDidChange = { [weak self] models in
            self?.forward(.mainKinds(models))
        }
        bridge.promotionsDidChange = { [weak self] models in
            self?.forward(.promotions(models))
        }
        bridge.accessoriesDidChange = { [weak self] models in
            self?.forward(.accessories(models))
        }
        bridge.foodDidChange = { [weak self] models in
            self?.forward(.food(models))
        }
        bridge.advertisementsDidChange = { [weak self] models in
            self?.forward(.advertisements(models))
        }
        bridge.nearbyAdvertisementsDidChange = { [weak self] models, fallback in
            self?.forward(
                .nearbyAdvertisements(models, showingRecentFallback: fallback)
            )
        }
        bridge.servicesDidChange = { [weak self] models in
            self?.forward(.services(models))
        }
        bridge.petProfilesDidChange = { [weak self] models in
            self?.forward(.petProfiles(models))
        }
        bridge.petRemindersDidChange = { [weak self] models in
            self?.forward(.petReminders(models))
        }
        bridge.ordersDidChange = { [weak self] models in
            self?.forward(.orders(models))
        }
        bridge.homeConfigDidChange = {
            [weak self] sections,
            titleViewMode,
            premiumCareVisible,
            novaFloatingVisible,
            backgroundGlowsFaded,
            fromCache in
            self?.forward(
                .homeConfig(
                    sections: sections,
                    titleViewMode: titleViewMode,
                    premiumCareVisible: premiumCareVisible,
                    novaFloatingVisible: novaFloatingVisible,
                    backgroundGlowsFaded: backgroundGlowsFaded,
                    fromCache: fromCache
                )
            )
        }
        bridge.locationDidChange = {
            [weak self] state,
            areaName,
            coordinate,
            hasCoordinate,
            manual in
            self?.forward(
                .location(
                    state: state,
                    areaName: areaName,
                    coordinate: hasCoordinate ? coordinate : nil,
                    manual: manual
                )
            )
        }
        bridge.sourceDidFail = { [weak self] source, error in
            self?.forward(
                .failure(sourceRawValue: source.rawValue, error: error)
            )
        }
    }

    nonisolated private func forward(_ event: HomeRepositoryEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
