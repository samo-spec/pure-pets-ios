import Foundation
import UIKit

@MainActor
final class PPAccessoryViewerStore: ObservableObject {
    @Published private(set) var phase: PPAccessoryViewerScreenPhase = .loading
    @Published private(set) var snapshot: PPAccessoryViewerSnapshot?
    @Published private(set) var ownerPhase: PPAccessoryViewerSectionPhase = .idle
    @Published private(set) var owner: PPAccessoryViewerOwner?
    @Published private(set) var suggestionsPhase:
        PPAccessoryViewerSectionPhase = .idle
    @Published private(set) var suggestions:
        [PPAccessoryViewerSuggestion] = []
    @Published private(set) var suggestionsFromSameProvider = false
    @Published private(set) var favoritePhase:
        PPAccessoryViewerSectionPhase = .idle
    @Published private(set) var isFavorite = false
    @Published private(set) var cartPhase: PPAccessoryViewerCartPhase = .ready
    @Published private(set) var livePhase: PPAccessoryViewerLivePhase = .current
    @Published private(set) var stockNotificationPhase:
        PPAccessoryViewerStockNotificationPhase = .idle
    @Published private(set) var quantity = 1
    @Published private(set) var cartQuantity = 0
    @Published private(set) var cartItemsCount = 0
    @Published private(set) var remainingStock = 0
    @Published private(set) var pricePulseToken = 0
    @Published private(set) var scrollToSuggestionsToken = 0
    @Published private(set) var bannerMessage: String?

    private var accessory: PetAccessory?
    private weak var presenter: UIViewController?
    private var didLoad = false
    private var successResetTask: Task<Void, Never>?
    private var liveRegistration: Any?

    init(accessory: PetAccessory?, presenter: UIViewController) {
        self.accessory = accessory
        self.presenter = presenter
    }

    deinit {
        successResetTask?.cancel()
        if let registration = liveRegistration as? NSObject {
            registration.perform(Selector(("remove")))
        }
    }

    func load() async {
        guard !didLoad else {
            refreshCartState()
            return
        }
        didLoad = true

        // Preserve the prepared loading frame before resolving injected data.
        await Task.yield()
        guard let accessory else {
            phase = .failed(
                message: PPAccessoryViewerL10n.text(
                    "accessory_view_unavailable_message"
                )
            )
            return
        }

        let resolvedSnapshot = PPAccessoryViewerSnapshot(
            accessory: accessory
        )
        snapshot = resolvedSnapshot
        refreshCartState()
        phase = .loaded

        let urls = resolvedSnapshot.media.compactMap(\.imageURL)
        PPAccessoryViewerLegacyBridge.prefetch(urls: urls)
        loadOwner()
        loadSuggestions()
        loadFavorite()
        startLiveListener()
    }

    func retry() {
        guard let accessory else {
            phase = .failed(
                message: PPAccessoryViewerL10n.text(
                    "accessory_view_unavailable_message"
                )
            )
            return
        }
        snapshot = PPAccessoryViewerSnapshot(accessory: accessory)
        phase = .loaded
        loadOwner()
        loadSuggestions()
        loadFavorite()
        refreshCartState()
        startLiveListener()
    }

    func retryOwner() {
        loadOwner()
    }

    func retrySuggestions() {
        loadSuggestions()
    }

    var totalPriceText: String {
        guard let accessory else { return snapshot?.price ?? "" }
        return PPAccessoryViewerLegacyBridge.formattedPrice(
            for: accessory,
            quantity: quantity
        )
    }

    var isPurchaseDataCurrent: Bool {
        livePhase == .current
    }

    var hasSimilarAlternatives: Bool {
        suggestionsPhase == .loaded &&
            suggestions.contains(where: \.isAvailable)
    }

    var canAskSeller: Bool {
        guard ownerPhase == .loaded, let owner else { return false }
        return !snapshotIsOwnItem && owner.isChatAllowed
    }

    private var snapshotIsOwnItem: Bool {
        snapshot?.isOwnItem == true
    }

    func refreshCartState() {
        guard let accessory else { return }
        cartQuantity =
            PPAccessoryViewerLegacyBridge.cartQuantity(for: accessory)
        cartItemsCount = PPAccessoryViewerLegacyBridge.cartItemsCount()
        remainingStock = max(accessory.quantity - cartQuantity, 0)
        quantity = min(max(quantity, 1), max(remainingStock, 1))
    }

    func incrementQuantity() {
        guard cartPhase != .processing, quantity < remainingStock else {
            return
        }
        quantity += 1
        pricePulseToken += 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    func decrementQuantity() {
        guard cartPhase != .processing, quantity > 1 else { return }
        quantity -= 1
        pricePulseToken += 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    /// Async bridge for ``AnimatedAddToCartButton``.
    ///
    /// Returns the updated total cart items count on success.
    /// Throws on any failure so the animated button can show its retry state.
    func addToCartAsync() async throws -> AnimatedAddToCartOutcome {
        guard let accessory,
              let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              remainingStock > 0,
              cartPhase != .processing,
              let presenter else {
            throw PPAccessoryCartError.unavailable
        }

        let requestedQuantity = quantity
        cartPhase = .processing
        successResetTask?.cancel()

        return try await withCheckedThrowingContinuation { continuation in
            PPAccessoryViewerLegacyBridge.addToCart(
                accessory,
                quantity: requestedQuantity,
                from: presenter
            ) { [weak self] result, addedQuantity, cartQuantity, remainingStock in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                        return
                    }
                    self.cartQuantity = cartQuantity
                    self.cartItemsCount =
                        PPAccessoryViewerLegacyBridge.cartItemsCount()
                    self.remainingStock = remainingStock

                    switch result {
                    case .success:
                        self.cartPhase = .success
                        self.quantity = 1
                        self.scheduleSuccessReset()
                        continuation.resume(
                            returning: AnimatedAddToCartOutcome(
                                cartCount: self.cartItemsCount,
                                addedQuantity: addedQuantity
                            )
                        )
                    case .cancelled, .authenticationRequired:
                        self.cartPhase = .ready
                        continuation.resume(
                            throwing: CancellationError()
                        )
                    case .offline:
                        self.cartPhase = .failed
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_cart_offline"
                        )
                        self.scheduleFailureReset()
                        continuation.resume(
                            throwing: PPAccessoryCartError.offline
                        )
                    case .outOfStock:
                        self.cartPhase = .failed
                        self.bannerMessage =
                            PPAccessoryViewerL10n.text("Out of stock")
                        self.scheduleFailureReset()
                        continuation.resume(
                            throwing: PPAccessoryCartError.outOfStock
                        )
                    case .unavailable:
                        self.cartPhase = .failed
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_item_unavailable"
                        )
                        self.scheduleFailureReset()
                        continuation.resume(
                            throwing: PPAccessoryCartError.unavailable
                        )
                    case .failed:
                        self.cartPhase = .failed
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_add_failed"
                        )
                        self.scheduleFailureReset()
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                    @unknown default:
                        self.cartPhase = .failed
                        self.scheduleFailureReset()
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                    }
                }
            }
        }
    }

    func registerStockNotification() {
        guard let accessory,
              snapshot?.canRequestStockNotification == true,
              stockNotificationPhase != .processing else {
            return
        }

        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            guard let presenter else { return }
            PPAccessoryViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { [weak self] signedIn in
                Task { @MainActor in
                    guard signedIn else { return }
                    self?.registerStockNotification()
                }
            }
            return
        }

        stockNotificationPhase = .processing
        PPAccessoryViewerLegacyBridge.registerStockNotification(
            for: accessory
        ) { [weak self] succeeded in
            Task { @MainActor in
                guard let self else { return }
                self.stockNotificationPhase =
                    succeeded ? .success : .failed
                if !succeeded {
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        "stock_notify_failed"
                    )
                }
            }
        }
    }

    func showSimilarAlternatives() {
        guard suggestionsPhase == .loaded, !suggestions.isEmpty else {
            return
        }
        scrollToSuggestionsToken += 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    func retryLiveUpdates() {
        guard livePhase == .stale else { return }
        livePhase = .refreshing
        startLiveListener()
    }

    func resume() {
        guard didLoad else { return }
        refreshCartState()
        loadFavorite()
        if liveRegistration == nil {
            startLiveListener()
        }
    }

    func pause() {
        successResetTask?.cancel()
        stopLiveListener()
    }


    func toggleFavorite() {
        guard let accessory, favoritePhase != .loading else { return }
        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            guard let presenter else { return }
            PPAccessoryViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { [weak self] signedIn in
                Task { @MainActor in
                    if signedIn {
                        self?.loadFavorite()
                    }
                }
            }
            return
        }

        let nextValue = !isFavorite
        favoritePhase = .loading
        PPAccessoryViewerLegacyBridge.setFavorite(
            nextValue,
            accessoryID: accessory.accessoryID
        ) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if error == nil {
                    self.isFavorite = nextValue
                    self.favoritePhase = .loaded
                    PPAccessoryViewerLegacyBridge.playFavoriteFeedback(
                        isFavorite: nextValue
                    )
                } else {
                    self.favoritePhase = .failed(
                        message: PPAccessoryViewerL10n.text(
                            "accessory_view_favorite_failed"
                        )
                    )
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        "accessory_view_favorite_failed"
                    )
                }
            }
        }
    }

    func dismissBanner() {
        bannerMessage = nil
    }

    func share() {
        guard let accessory, let presenter else { return }
        PPAccessoryViewerLegacyBridge.share(accessory, from: presenter)
    }

    func close() {
        guard let presenter else { return }
        PPAccessoryViewerLegacyBridge.close(from: presenter)
    }

    func openCart() {
        guard let presenter else { return }
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
        PPAccessoryViewerLegacyBridge.openCart(from: presenter)
    }

    func openSuggestion(_ suggestion: PPAccessoryViewerSuggestion) {
        guard let presenter else { return }
        PPAccessoryViewerLegacyBridge.openAccessory(
            suggestion.accessory,
            from: presenter
        )
    }

    func openSellerProfile() {
        guard let accessory,
              let owner,
              let presenter else { return }
        PPAccessoryViewerLegacyBridge.openSellerProfile(
            accessory: accessory,
            owner: owner.user,
            suggestions: suggestions.map(\.accessory),
            from: presenter
        )
    }

    func callOwner() {
        guard let accessory,
              let owner,
              let presenter else { return }
        PPAccessoryViewerLegacyBridge.call(
            owner: owner.user,
            accessory: accessory,
            from: presenter
        )
    }

    func chatWithOwner() {
        guard let accessory,
              let owner,
              let presenter else { return }
        PPAccessoryViewerLegacyBridge.chat(
            owner: owner.user,
            accessory: accessory,
            from: presenter
        )
    }

    func openSupport() {
        guard let presenter else { return }
        PPAccessoryViewerLegacyBridge.openSupport(from: presenter)
    }

    private func loadOwner() {
        guard let accessory else { return }
        ownerPhase = .loading
        PPAccessoryViewerLegacyBridge.fetchOwner(
            for: accessory
        ) { [weak self] user, error in
            Task { @MainActor in
                guard let self else { return }
                if let user {
                    let baseAvatarURL =
                        PPAccessoryViewerLegacyBridge.avatarURL(for: user) ??
                        "<nil>"
                    print(
                        "[PPAccessoryViewer][SellerImage] Loaded owner model. ownerID=\(accessory.ownerID) baseAvatarURL=\(baseAvatarURL)"
                    )
                    self.owner = PPAccessoryViewerOwner(user: user)
                    self.ownerPhase = .loaded
                    self.loadProviderProfileImageIfNeeded(
                        for: user,
                        ownerID: accessory.ownerID
                    )
                } else if error != nil {
                    self.owner = nil
                    self.ownerPhase = .failed(
                        message: PPAccessoryViewerL10n.text(
                            "accessory_view_owner_failed"
                        )
                    )
                } else {
                    self.owner = nil
                    self.ownerPhase = .empty
                }
            }
        }
    }

    private func loadProviderProfileImageIfNeeded(
        for user: UserModel,
        ownerID: String
    ) {
        guard snapshot?.isProviderMarketplace == true else {
            print(
                "[PPAccessoryViewer][SellerImage] Skipping provider profile image fetch because accessory is not marketplace. ownerID=\(ownerID)"
            )
            return
        }
        let cleanOwnerID = ownerID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanOwnerID.isEmpty else {
            print(
                "[PPAccessoryViewer][SellerImage] Skipping provider profile image fetch because ownerID is empty."
            )
            return
        }

        PPAccessoryViewerLegacyBridge.fetchProviderProfileImageURL(
            ownerID: cleanOwnerID
        ) { [weak self] imageURL in
            Task { @MainActor in
                guard let self else { return }
                let currentOwnerID = self.accessory?.ownerID.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard currentOwnerID == cleanOwnerID else {
                    print(
                        "[PPAccessoryViewer][SellerImage] Dropping provider profile image result because owner changed. expected=\(cleanOwnerID) current=\(currentOwnerID ?? "<nil>")"
                    )
                    return
                }
                guard let imageURL = imageURL?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ), !imageURL.isEmpty else {
                    let fallbackAvatarURL =
                        PPAccessoryViewerLegacyBridge.avatarURL(for: user) ??
                        "<nil>"
                    print(
                        "[PPAccessoryViewer][SellerImage] Provider profile image missing; keeping fallback avatar. ownerID=\(cleanOwnerID) fallbackAvatarURL=\(fallbackAvatarURL)"
                    )
                    return
                }

                print(
                    "[PPAccessoryViewer][SellerImage] Applying provider profile image. ownerID=\(cleanOwnerID) imageURL=\(imageURL)"
                )
                self.owner = PPAccessoryViewerOwner(
                    user: user,
                    companyProfileImageURL: imageURL
                )
            }
        }
    }

    private func loadSuggestions() {
        guard let accessory else { return }
        suggestionsPhase = .loading
        PPAccessoryViewerLegacyBridge.fetchSuggestions(
            for: accessory
        ) { [weak self] items, sameProvider, error in
            Task { @MainActor in
                guard let self else { return }
                var seen = Set<String>()
                self.suggestions = items
                    .filter {
                        !$0.isBlocked &&
                        !$0.isDeleted &&
                        !$0.isDisabled &&
                        $0.accessoryID != accessory.accessoryID
                    }
                    .map(PPAccessoryViewerSuggestion.init(accessory:))
                    .filter { seen.insert($0.id).inserted }
                    .sorted { left, right in
                        if left.isAvailable != right.isAvailable {
                            return left.isAvailable && !right.isAvailable
                        }
                        return left.id.localizedStandardCompare(right.id)
                            == .orderedAscending
                    }
                self.suggestionsFromSameProvider = sameProvider
                if !self.suggestions.isEmpty {
                    self.suggestionsPhase = .loaded
                } else if error != nil {
                    self.suggestionsPhase = .failed(
                        message: PPAccessoryViewerL10n.text(
                            "accessory_view_suggestions_failed"
                        )
                    )
                } else {
                    self.suggestionsPhase = .empty
                }
            }
        }
    }

    private func loadFavorite() {
        guard let accessory else { return }
        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            isFavorite = false
            favoritePhase = .idle
            return
        }
        favoritePhase = .loading
        PPAccessoryViewerLegacyBridge.loadFavorite(
            accessoryID: accessory.accessoryID
        ) { [weak self] favorite, error in
            Task { @MainActor in
                guard let self else { return }
                self.isFavorite = favorite
                self.favoritePhase = error == nil
                    ? .loaded
                    : .failed(
                        message: PPAccessoryViewerL10n.text(
                            "accessory_view_favorite_failed"
                        )
                    )
            }
        }
    }

    private func scheduleSuccessReset() {
        successResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.cartPhase = .ready
        }
    }

    private func scheduleFailureReset() {
        successResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.cartPhase = .ready
        }
    }

    private func startLiveListener() {
        guard let accessoryID = accessory?.accessoryID, !accessoryID.isEmpty else { return }
        stopLiveListener()
        liveRegistration = PPAccessoryViewerLegacyBridge.listenToAccessory(
            accessoryID: accessoryID,
            onUpdate: { [weak self] status, updatedAccessory in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .updated:
                    guard let updatedAccessory else { return }
                    let oldPrice = self.snapshot?.price
                    let oldQuantity = self.snapshot?.quantity
                    let nextSnapshot = PPAccessoryViewerSnapshot(
                        accessory: updatedAccessory
                    )
                    self.accessory = updatedAccessory
                    self.snapshot = nextSnapshot
                    self.livePhase = nextSnapshot.isUnavailable
                        ? .deleted
                        : .current
                    self.refreshCartState()

                    if oldPrice != nextSnapshot.price {
                        self.pricePulseToken += 1
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_live_price_updated"
                        )
                    } else if oldQuantity != nextSnapshot.quantity {
                        self.bannerMessage =
                            PPAccessoryViewerL10n.formatted(
                                "accessory_view_live_stock_updated_format",
                                PPAccessoryViewerL10n.integer(
                                    nextSnapshot.quantity
                                )
                            )
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: self.bannerMessage
                        )
                    }

                    if nextSnapshot.isUnavailable {
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_live_product_removed"
                        )
                    }
                case .missing:
                    self.livePhase = .deleted
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        "accessory_view_live_product_removed"
                    )
                case .failed:
                    self.livePhase = .stale
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        "accessory_view_live_data_stale"
                    )
                @unknown default:
                    self.livePhase = .stale
                }
            }
        })
    }

    private func stopLiveListener() {
        if let registration = liveRegistration as? NSObject {
            registration.perform(Selector(("remove")))
        }
        liveRegistration = nil
    }
}
