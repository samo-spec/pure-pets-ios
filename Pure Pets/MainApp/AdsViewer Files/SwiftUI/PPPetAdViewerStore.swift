import Combine
import Foundation
import UIKit

@MainActor
final class PPPetAdViewerStore: ObservableObject {
    @Published private(set) var snapshot: PPPetAdViewerSnapshot

    @Published private(set) var screenState: PPPetAdViewerScreenState
    @Published private(set) var ownerState: PPPetAdViewerSectionState = .idle
    @Published private(set) var relatedAdsState: PPPetAdViewerSectionState = .idle
    @Published private(set) var accessoriesState: PPPetAdViewerSectionState = .idle
    @Published private(set) var favoriteState: PPPetAdViewerActionState = .idle
    @Published private(set) var reportState: PPPetAdViewerActionState = .idle
    @Published private(set) var chatState: PPPetAdViewerActionState = .idle
    @Published private(set) var owner: PPPetAdOwner?
    @Published private(set) var relatedAds: [PPPetAdRelatedItem] = []
    @Published private(set) var relatedAccessories: [PPPetAdRelatedItem] = []
    @Published private(set) var isFavorite: Bool
    @Published private(set) var selectedPetAd: PetAd?
    @Published var isRelatedViewerPresented = false
    @Published var selectedMediaIndex = 0
    @Published var isMediaViewerPresented = false
    @Published var isReportDialogPresented = false
    @Published private(set) var toastMessage: String?

    private let repository: PPPetAdViewerRepository
    private let hostActions: PPPetAdViewerHostActions
    private var ownerTask: Task<Void, Never>?
    private var relatedAdsTask: Task<Void, Never>?
    private var accessoriesTask: Task<Void, Never>?
    private var favoriteLoadTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var didStart = false

    init(
        ad: PetAd,
        repository: PPPetAdViewerRepository,
        hostActions: PPPetAdViewerHostActions
    ) {
        self.repository = repository
        self.hostActions = hostActions
        let initialSnapshot = repository.makeSnapshot(for: ad)
        snapshot = initialSnapshot
        isFavorite = ad.isFavorite
        screenState =
            initialSnapshot.hasRenderableContent ? .content : .empty
    }

    deinit {
        ownerTask?.cancel()
        relatedAdsTask?.cancel()
        accessoriesTask?.cancel()
        favoriteLoadTask?.cancel()
        toastTask?.cancel()
    }

    var isSignedIn: Bool {
        repository.isSignedIn
    }

    var isViewingOwnAdvertisement: Bool {
        guard let currentUserID = repository.currentUserID else {
            return false
        }
        return !currentUserID.isEmpty &&
            currentUserID == snapshot.ad.ownerID
    }

    var canReport: Bool {
        !snapshot.ad.adID.isEmpty && !isViewingOwnAdvertisement
    }

    var canCallOwner: Bool {
        isSignedIn &&
            !isViewingOwnAdvertisement &&
            owner?.phoneNumber?.isEmpty == false
    }

    var canMessageOwner: Bool {
        isSignedIn &&
            !isViewingOwnAdvertisement &&
            owner?.isChatAllowed == true
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        repository.logView(ad: snapshot.ad)
        repository.track(.view, ad: snapshot.ad)
        refresh()
    }

    func refresh() {
        guard snapshot.hasRenderableContent else {
            screenState = .empty
            return
        }

        screenState = .content
        loadOwner()
        loadRelatedAds()
        loadAccessories()
        loadFavorite()
    }

    func refreshLocalization() {
        snapshot = repository.makeSnapshot(for: snapshot.ad)
        relatedAds = relatedAds.map(localizedRelatedItem)
        relatedAccessories =
            relatedAccessories.map(localizedRelatedItem)
        screenState = snapshot.hasRenderableContent ? .content : .empty
    }

    func refreshAuthenticationState() {
        if !isSignedIn {
            ownerTask?.cancel()
            favoriteLoadTask?.cancel()
            owner = nil
            ownerState = .idle
            isFavorite = false
            favoriteState = .idle
            isReportDialogPresented = false
            reportState = .idle
            chatState = .idle
            return
        }
        loadOwner()
        loadFavorite()
    }

    func retryOwner() {
        loadOwner()
    }

    func retryRelatedAds() {
        loadRelatedAds()
    }

    func retryAccessories() {
        loadAccessories()
    }

    func close() {
        hostActions.close()
    }

    func selectMedia(at index: Int) {
        guard snapshot.media.indices.contains(index) else { return }
        selectedMediaIndex = index
        isMediaViewerPresented = true
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func selectRelatedItem(_ item: PPPetAdRelatedItem) {
        switch item.kind {
        case let .petAd(ad):
            guard ad.adID != snapshot.ad.adID else { return }
            selectedPetAd = ad
            isRelatedViewerPresented = true
            UISelectionFeedbackGenerator().selectionChanged()
        case let .accessory(accessory):
            UISelectionFeedbackGenerator().selectionChanged()
            hostActions.open(accessory: accessory)
        }
    }

    func share() {
        hostActions.share(ad: snapshot.ad)
        repository.track(.share, ad: snapshot.ad)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func requestReport() {
        guard canReport, reportState != .working else { return }
        if !isSignedIn {
            Task { [weak self] in
                guard let self else { return }
                _ = await hostActions.requireSignIn()
            }
            return
        }

        guard repository.isNetworkAvailable else {
            showToast(offlineMessage)
            return
        }
        isReportDialogPresented = true
    }

    func submitReport(reason: PPPetAdReportReason) {
        guard canReport, reportState != .working else { return }
        guard repository.isNetworkAvailable else {
            reportState = .failed(message: offlineMessage)
            showToast(offlineMessage)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            reportState = .working
            do {
                try await repository.submitReport(
                    for: snapshot.ad,
                    reason: reason
                )
                let message = PPPetAdLocalization.text(
                    "report_submit_message",
                    fallback: "Thank you. Our team will review this report."
                )
                reportState = .succeeded(message: message)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
                showToast(message)
            } catch {
                let message = PPPetAdLocalization.text(
                    "report_submit_failed_message",
                    fallback:
                        "Failed to submit the report. Please try again."
                )
                reportState = .failed(message: message)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.error)
                showToast(message)
            }
        }
    }

    func toggleFavorite() {
        guard !snapshot.ad.adID.isEmpty,
              favoriteState != .working else {
            return
        }

        if !isSignedIn {
            Task { [weak self] in
                guard let self else { return }
                _ = await hostActions.requireSignIn()
            }
            return
        }

        guard repository.isNetworkAvailable else {
            favoriteState = .failed(message: offlineMessage)
            showToast(offlineMessage)
            return
        }

        favoriteLoadTask?.cancel()
        let previousValue = isFavorite
        let nextValue = !previousValue
        isFavorite = nextValue
        favoriteState = .working

        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.setFavorite(
                    nextValue,
                    adID: snapshot.ad.adID
                )
                let message = nextValue
                    ? PPPetAdLocalization.text(
                        "pet_ad_viewer_saved",
                        fallback: "Saved to favorites"
                    )
                    : PPPetAdLocalization.text(
                        "pet_ad_viewer_removed",
                        fallback: "Removed from favorites"
                    )
                favoriteState = .succeeded(message: message)
                PPPetAdViewerLegacyBridge.playFavoriteFeedback(
                    isFavorite: nextValue
                )
                showToast(message)
            } catch {
                isFavorite = previousValue
                let message = PPPetAdLocalization.text(
                    "load_error_retry",
                    fallback: "Something went wrong. Please try again."
                )
                favoriteState = .failed(message: message)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.error)
                showToast(message)
            }
        }
    }

    func callOwner() {
        guard let owner, canCallOwner else { return }
        repository.logContact(ad: snapshot.ad, channelCode: 0)
        repository.track(.call, ad: snapshot.ad)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hostActions.call(owner: owner)
    }

    func openWhatsApp() {
        guard let owner, canCallOwner else { return }
        repository.logContact(ad: snapshot.ad, channelCode: 2)
        if owner.phoneNumber?.rangeOfCharacter(
            from: .decimalDigits
        ) != nil {
            repository.track(.chat, ad: snapshot.ad)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hostActions.openWhatsApp(owner: owner)
    }

    func openChat() {
        guard let owner,
              canMessageOwner,
              chatState != .working else {
            return
        }
        guard repository.isNetworkAvailable else {
            showToast(offlineMessage)
            return
        }

        chatState = .working
        Task { [weak self] in
            guard let self else { return }
            repository.logContact(ad: snapshot.ad, channelCode: 1)
            do {
                try await hostActions.openChat(owner: owner)
                chatState = .succeeded(message: "")
                repository.track(.chat, ad: snapshot.ad)
            } catch {
                let message =
                    error.localizedDescription.isEmpty
                    ? PPPetAdLocalization.text(
                        "unknownError",
                        fallback: "The chat could not be opened."
                    )
                    : error.localizedDescription
                chatState = .failed(message: message)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.error)
                showToast(message)
            }
        }
    }

    func requireSignInForContact() {
        Task { [weak self] in
            guard let self else { return }
            if await hostActions.requireSignIn() {
                refresh()
            }
        }
    }

    private func loadOwner() {
        ownerTask?.cancel()

        guard isSignedIn else {
            owner = nil
            ownerState = .idle
            return
        }
        guard !isViewingOwnAdvertisement else {
            owner = nil
            ownerState = .idle
            return
        }

        let ownerID = snapshot.ad.ownerID
        guard !ownerID.isEmpty else {
            owner = nil
            ownerState = .empty
            return
        }
        guard repository.isNetworkAvailable else {
            owner = nil
            ownerState = .offline(message: offlineMessage)
            return
        }

        ownerState = .loading
        let dataSource = repository
        ownerTask = Task { [weak self] in
            do {
                let value =
                    try await dataSource.loadOwner(ownerID: ownerID)
                guard !Task.isCancelled, let self else { return }
                self.owner = value
                self.ownerState = value == nil ? .empty : .loaded
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.owner = nil
                self.ownerState = self.sectionFailure(for: error)
            }
        }
    }

    private func loadRelatedAds() {
        relatedAdsTask?.cancel()
        guard repository.isNetworkAvailable else {
            relatedAds = []
            relatedAdsState = .offline(message: offlineMessage)
            return
        }
        relatedAdsState = .loading
        let dataSource = repository
        let ad = snapshot.ad
        relatedAdsTask = Task { [weak self] in
            do {
                let items = try await dataSource.loadRelatedAds(
                    for: ad,
                    limit: 15
                )
                guard !Task.isCancelled, let self else { return }
                self.relatedAds = items
                self.relatedAdsState =
                    items.isEmpty ? .empty : .loaded
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.relatedAds = []
                self.relatedAdsState =
                    self.sectionFailure(for: error)
            }
        }
    }

    private func loadAccessories() {
        accessoriesTask?.cancel()
        guard repository.isNetworkAvailable else {
            relatedAccessories = []
            accessoriesState = .offline(message: offlineMessage)
            return
        }
        accessoriesState = .loading
        let dataSource = repository
        let ad = snapshot.ad
        accessoriesTask = Task { [weak self] in
            do {
                let items =
                    try await dataSource.loadRelatedAccessories(
                    for: ad,
                    limit: 15
                )
                guard !Task.isCancelled, let self else { return }
                self.relatedAccessories = items
                self.accessoriesState =
                    items.isEmpty ? .empty : .loaded
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.relatedAccessories = []
                self.accessoriesState =
                    self.sectionFailure(for: error)
            }
        }
    }

    private func loadFavorite() {
        favoriteLoadTask?.cancel()
        guard isSignedIn,
              favoriteState != .working,
              !snapshot.ad.adID.isEmpty else {
            return
        }
        guard repository.isNetworkAvailable else { return }

        let dataSource = repository
        let adID = snapshot.ad.adID
        favoriteLoadTask = Task { [weak self] in
            do {
                let value = try await dataSource.loadFavorite(
                    adID: adID
                )
                guard !Task.isCancelled, let self else { return }
                self.isFavorite = value
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.favoriteState =
                    .failed(
                        message: PPPetAdLocalization.text(
                            "pet_ad_viewer_section_error_message",
                            fallback:
                                "We couldn’t load this information. Please try again."
                        )
                    )
            }
        }
    }

    private func localizedRelatedItem(
        _ item: PPPetAdRelatedItem
    ) -> PPPetAdRelatedItem {
        switch item.kind {
        case let .petAd(ad):
            return PPPetAdRelatedItem(ad: ad)
        case let .accessory(accessory):
            return PPPetAdRelatedItem(accessory: accessory)
        }
    }

    private func sectionFailure(
        for error: Error
    ) -> PPPetAdViewerSectionState {
        let value = error as NSError
        if isOfflineError(value) {
            return .offline(
                message: PPPetAdLocalization.text(
                    "pet_ad_viewer_offline_message",
                    fallback:
                        "You appear to be offline. Check your connection and retry."
                )
            )
        }
        return .failed(
            message: PPPetAdLocalization.text(
                "pet_ad_viewer_section_error_message",
                fallback:
                    "We couldn’t load this information. Please try again."
            )
        )
    }

    private func isOfflineError(_ error: NSError) -> Bool {
        let offlineCodes: Set<Int> = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorDataNotAllowed
        ]
        if error.domain == NSURLErrorDomain,
           offlineCodes.contains(error.code) {
            return true
        }
        if error.domain == "FIRFirestoreErrorDomain",
           [4, 14].contains(error.code) {
            return true
        }
        if let underlying =
            error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isOfflineError(underlying)
        }
        return false
    }

    private var offlineMessage: String {
        PPPetAdLocalization.text(
            "pet_ad_viewer_offline_message",
            fallback:
                "You appear to be offline. Check your connection and retry."
        )
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
