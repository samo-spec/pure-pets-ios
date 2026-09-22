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
    @Published private(set) var checkoutPhase:
        PPAccessoryViewerCheckoutPhase = .ready
    @Published private(set) var livePhase: PPAccessoryViewerLivePhase = .current
    @Published private(set) var stockNotificationPhase:
        PPAccessoryViewerStockNotificationPhase = .idle
    @Published private(set) var quantity = 1
    @Published private(set) var cartQuantity = 0
    @Published private(set) var cartItemsCount = 0
    @Published private(set) var remainingStock = 0
    @Published private(set) var checkoutSelectionTotalText = ""
    @Published private(set) var checkoutCartSubtotalText = ""
    @Published private(set) var checkoutUnitsCount = 0
    @Published private(set) var checkoutRequiresProviderSwitch = false
    @Published private(set) var checkoutPreviewCanCommit = false
    @Published private(set) var pricePulseToken = 0
    @Published private(set) var scrollToSuggestionsToken = 0
    @Published private(set) var bannerMessage: String?

    /// Option definitions configured for this product family (e.g. Color, Size, Weight).
    @Published private(set) var optionDefinitions: [PPAccessoryViewerOptionDefinition] = []
    /// Currently selected option values: [optionId: valueId] (e.g. ["color": "black", "size": "s"]).
    @Published private(set) var selectedOptions: [String: String] = [:]
    /// Active variant matching current selection (if resolved).
    @Published private(set) var currentVariant: PPAccessoryViewerVariant?

    /// Sibling variants of the product being viewed, in server order. Empty for a
    /// standalone product, which is the overwhelming majority.
    @Published private(set) var variants: [PPAccessoryViewerVariant] = []
    @Published private(set) var variantsPhase:
        PPAccessoryViewerSectionPhase = .idle
    /// Product id of the variant currently being resolved, so exactly one swatch/pill can
    /// show progress and the rest can be disabled without freezing the whole screen.
    @Published private(set) var switchingVariantProductId: String?

    private var accessory: PetAccessory?
    private weak var presenter: UIViewController?
    private var didLoad = false
    private var successResetTask: Task<Void, Never>?
    private var checkoutTask: Task<Void, Never>?
    private var preparedCheckoutCartQuantity: Int?
    private var liveRegistration: Any?
    private var cartObserver: NSObjectProtocol?

    private enum CartMutationPresentation: Equatable {
        case cart
        case checkout
    }

    init(accessory: PetAccessory?, presenter: UIViewController) {
        self.accessory = accessory
        self.presenter = presenter
        cartObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("CartUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshCartState()
            }
        }
    }

    deinit {
        successResetTask?.cancel()
        checkoutTask?.cancel()
        if let cartObserver {
            NotificationCenter.default.removeObserver(cartObserver)
        }
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
        loadVariants()
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
        loadVariants()
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
        checkoutSelectionTotalText.isEmpty
            ? (snapshot?.price ?? "")
            : checkoutSelectionTotalText
    }

    var isPurchaseDataCurrent: Bool {
        livePhase == .current
    }

    var isCheckoutProcessing: Bool {
        checkoutPhase == .preparingCart ||
            checkoutPhase == .openingPayment
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
        refreshCheckoutPreview()
        reconcilePreparedCheckoutState()
    }

    func incrementQuantity() {
        guard cartPhase != .processing,
              !isCheckoutProcessing,
              quantity < remainingStock else {
            return
        }
        quantity += 1
        refreshCheckoutPreview()
        pricePulseToken += 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    func decrementQuantity() {
        guard cartPhase != .processing,
              !isCheckoutProcessing,
              quantity > 1 else { return }
        quantity -= 1
        refreshCheckoutPreview()
        pricePulseToken += 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    /// Async bridge for ``AnimatedAddToCartButton``.
    ///
    /// Returns the updated total cart items count on success.
    /// Throws on any failure so the animated button can show its retry state.
    func addToCartAsync() async throws -> AnimatedAddToCartOutcome {
        guard !isCheckoutProcessing else {
            throw PPAccessoryCartError.unavailable
        }
        return try await performCartMutation(presentation: .cart)
    }

    /// Updates the existing cart line through the legacy CartManager owner.
    /// This keeps PPCommerceCartHolder's quantity binding synchronized with
    /// the same local, Firestore-backed cart used by the UIKit checkout flow.
    func updateCartQuantity(_ requestedQuantity: Int) async throws -> Int {
        guard let accessory,
              let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              !isCheckoutProcessing,
              cartPhase != .processing,
              cartQuantity > 0 else {
            throw PPAccessoryCartError.unavailable
        }

        cartPhase = .processing
        return try await withCheckedThrowingContinuation { continuation in
            PPAccessoryViewerLegacyBridge.updateCartQuantity(
                requestedQuantity,
                for: accessory
            ) { [weak self] succeeded, cartQuantity, remainingStock in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                        return
                    }

                    self.cartQuantity = max(cartQuantity, 0)
                    self.remainingStock = max(remainingStock, 0)
                    self.quantity = min(
                        max(self.quantity, 1),
                        max(self.remainingStock, 1)
                    )
                    self.refreshCheckoutPreview()
                    self.cartPhase = .ready

                    if succeeded {
                        continuation.resume(returning: self.cartQuantity)
                    } else {
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                    }
                }
            }
        }
    }

    /// Opens the established payment selector for the confirmed cart state.
    /// The holder reports only that the handoff opened; payment confirmation
    /// remains owned by the existing checkout flow.
    func openCartCheckout() async throws {
        guard let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              cartQuantity > 0,
              let presenter else {
            throw PPAccessoryCartError.unavailable
        }

        guard PPAccessoryViewerLegacyBridge.isNetworkAvailable() else {
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_cart_offline"
            )
            throw PPAccessoryCartError.offline
        }

        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            PPAccessoryViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { _ in }
            throw CancellationError()
        }

        guard PPAccessoryViewerLegacyBridge.openPaymentSelection(
            from: presenter
        ) else {
            checkoutPhase = .routeFailed
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_checkout_route_failed"
            )
            throw PPAccessoryCartError.failed
        }

        checkoutPhase = .openingPayment
    }

    /// Opens payment for an immutable snapshot of the visible accessory and
    /// selected quantity. The shared cart is not prepared, synchronized, or
    /// used as the payment payload.
    func openDirectCheckout(quantity requestedQuantity: Int) async throws {
        guard let accessory,
              let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              !isCheckoutProcessing,
              requestedQuantity > 0,
              requestedQuantity <= max(snapshot.quantity, 0),
              let presenter else {
            throw PPAccessoryCartError.unavailable
        }

        guard PPAccessoryViewerLegacyBridge.isNetworkAvailable() else {
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_cart_offline"
            )
            throw PPAccessoryCartError.offline
        }

        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            PPAccessoryViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { _ in }
            throw CancellationError()
        }

        checkoutPhase = .openingPayment
        return try await withCheckedThrowingContinuation { continuation in
            PPAccessoryViewerLegacyBridge.beginDirectCheckout(
                accessory,
                quantity: requestedQuantity,
                from: presenter
            ) { [weak self] result in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                        return
                    }

                    switch result {
                    case .success:
                        continuation.resume()
                    case .cancelled, .authenticationRequired:
                        self.checkoutPhase = .ready
                        continuation.resume(throwing: CancellationError())
                    case .offline:
                        self.checkoutPhase = .ready
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_cart_offline"
                        )
                        continuation.resume(
                            throwing: PPAccessoryCartError.offline
                        )
                    case .outOfStock:
                        self.checkoutPhase = .ready
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "Out of stock"
                        )
                        continuation.resume(
                            throwing: PPAccessoryCartError.outOfStock
                        )
                    case .unavailable:
                        self.checkoutPhase = .ready
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_item_unavailable"
                        )
                        continuation.resume(
                            throwing: PPAccessoryCartError.unavailable
                        )
                    case .failed:
                        // Direct checkout does not prepare the shared cart.
                        // Keep this surface retryable so its holder can invoke
                        // the same explicit-item route again.
                        self.checkoutPhase = .ready
                        self.bannerMessage = PPAccessoryViewerL10n.text(
                            "accessory_view_direct_checkout_route_failed"
                        )
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                    @unknown default:
                        self.checkoutPhase = .ready
                        continuation.resume(
                            throwing: PPAccessoryCartError.failed
                        )
                    }
                }
            }
        }
    }

    func payNow() {
        guard !isCheckoutProcessing, cartPhase != .processing else { return }

        if checkoutPhase == .routeFailed {
            openPreparedCheckout()
            return
        }

        guard let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              checkoutPreviewCanCommit,
              remainingStock > 0 else {
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_item_unavailable"
            )
            return
        }

        checkoutPhase = .preparingCart
        checkoutTask?.cancel()
        checkoutTask = Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await self.performCartMutation(
                    presentation: .checkout
                )
                guard !Task.isCancelled else {
                    self.checkoutPhase = .ready
                    self.preparedCheckoutCartQuantity = nil
                    self.checkoutTask = nil
                    return
                }
                self.checkoutPhase = .openingPayment
                self.openPreparedCheckout()
            } catch is CancellationError {
                self.checkoutPhase = .ready
                self.preparedCheckoutCartQuantity = nil
                self.checkoutTask = nil
            } catch {
                self.checkoutPhase = .ready
                self.preparedCheckoutCartQuantity = nil
                self.checkoutTask = nil
            }
        }
    }

    private func performCartMutation(
        presentation: CartMutationPresentation
    ) async throws -> AnimatedAddToCartOutcome {
        let hasValidCheckoutPreview =
            presentation == .cart || checkoutPreviewCanCommit
        guard let accessory,
              let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              isPurchaseDataCurrent,
              hasValidCheckoutPreview,
              remainingStock > 0,
              cartPhase != .processing,
              let presenter else {
            throw PPAccessoryCartError.unavailable
        }

        let requestedQuantity = quantity
        cartPhase = .processing
        successResetTask?.cancel()

        return try await withCheckedThrowingContinuation { continuation in
            let completion: (
                PPAccessoryCartResultCode,
                Int,
                Int,
                Int
            ) -> Void = { [weak self] result,
                                   addedQuantity,
                                   cartQuantity,
                                   remainingStock in
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
                        if presentation == .checkout {
                            self.preparedCheckoutCartQuantity = cartQuantity
                        }
                        self.refreshCheckoutPreview()
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
                            presentation == .checkout
                                ? "accessory_view_checkout_sync_failed"
                                : "accessory_view_add_failed"
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

            switch presentation {
            case .cart:
                PPAccessoryViewerLegacyBridge.addToCart(
                    accessory,
                    quantity: requestedQuantity,
                    from: presenter,
                    completion: completion
                )
            case .checkout:
                PPAccessoryViewerLegacyBridge.prepareForCheckout(
                    accessory,
                    quantity: requestedQuantity,
                    from: presenter,
                    completion: completion
                )
            }
        }
    }

    private func openPreparedCheckout() {
        guard let presenter,
              PPAccessoryViewerLegacyBridge.openPaymentSelection(
                from: presenter
              ) else {
            checkoutPhase = .routeFailed
            cartPhase = .ready
            checkoutTask = nil
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_checkout_route_failed"
            )
            return
        }

        checkoutPhase = .openingPayment
        checkoutTask = nil
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
        if checkoutPhase == .openingPayment {
            checkoutPhase = .ready
            preparedCheckoutCartQuantity = nil
        }
        if cartPhase == .success && checkoutPhase != .preparingCart {
            cartPhase = .ready
        }
        refreshCartState()
        loadFavorite()
        if liveRegistration == nil {
            startLiveListener()
        }
    }

    func pause() {
        successResetTask?.cancel()
        if checkoutPhase == .preparingCart {
            checkoutTask?.cancel()
        }
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

    private func refreshCheckoutPreview() {
        guard let accessory else {
            checkoutSelectionTotalText = ""
            checkoutCartSubtotalText = ""
            checkoutUnitsCount = 0
            checkoutRequiresProviderSwitch = false
            checkoutPreviewCanCommit = false
            return
        }

        let preview = PPAccessoryViewerLegacyBridge.checkoutPreview(
            for: accessory,
            quantity: quantity
        )
        checkoutSelectionTotalText = preview.selectionTotalText
        checkoutCartSubtotalText = preview.cartSubtotalText
        checkoutUnitsCount = preview.unitsCount
        checkoutRequiresProviderSwitch = preview.requiresProviderSwitch
        checkoutPreviewCanCommit = preview.canCommit
    }

    private func reconcilePreparedCheckoutState() {
        guard checkoutPhase == .routeFailed,
              let preparedCheckoutCartQuantity,
              cartQuantity < preparedCheckoutCartQuantity else {
            return
        }
        checkoutPhase = .ready
        self.preparedCheckoutCartQuantity = nil
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

    // MARK: - Option & Variant Resolution

    /// Resolves the product's options and variants.
    ///
    /// Costs nothing for a standalone product: the bridge short-circuits when there is
    /// no `productFamilyId` and never touches Firestore.
    private func loadVariants() {
        guard let accessory else { return }
        let currentProductId = accessory.accessoryID

        variantsPhase = .loading
        PPAccessoryViewerLegacyBridge.fetchProductFamily(
            for: accessory
        ) { [weak self] family, error in
            Task { @MainActor in
                guard let self else { return }
                guard let family, error == nil else {
                    if error != nil {
                        self.variantsPhase = .failed(
                            message: PPAccessoryViewerL10n.text("accessory_view_options_failed")
                        )
                    } else {
                        self.variantsPhase = .empty
                    }
                    return
                }

                // 1. Parse raw variants
                let rawVariants = (family["variants"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
                var seen = Set<String>()
                let parsedVariants = rawVariants
                    .compactMap(PPAccessoryViewerVariant.init(projection:))
                    .filter { !$0.isArchived || $0.productId == currentProductId }
                    .filter { seen.insert($0.productId).inserted }

                self.variants = parsedVariants

                // 2. Parse option definitions
                let rawDefs = (family["optionDefinitions"] as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
                var parsedDefs = rawDefs.compactMap(PPAccessoryViewerOptionDefinition.init(dictionary:))

                // If no option definitions exist but legacy colour variants exist, synthesize Color option
                if parsedDefs.isEmpty && parsedVariants.contains(where: { !$0.hex.isEmpty || !$0.name.isEmpty }) {
                    var colorValues: [PPAccessoryViewerOptionValue] = []
                    var seenColorIds = Set<String>()
                    for variant in parsedVariants {
                        let colorId = variant.selectedOptions["color"] ?? variant.id
                        if seenColorIds.insert(colorId).inserted {
                            colorValues.append(
                                PPAccessoryViewerOptionValue(
                                    id: colorId,
                                    canonicalValue: variant.name,
                                    nameAr: variant.name,
                                    nameEn: variant.name,
                                    sortOrder: variant.sortOrder,
                                    hex: variant.hex.isEmpty ? nil : variant.hex
                                )
                            )
                        }
                    }
                    if !colorValues.isEmpty {
                        parsedDefs = [
                            PPAccessoryViewerOptionDefinition(
                                id: "color",
                                key: "color",
                                nameAr: PPAccessoryViewerL10n.text("accessory_view_colors_title"),
                                nameEn: "Color",
                                sortOrder: 0,
                                values: colorValues
                            )
                        ]
                    }
                }

                self.optionDefinitions = parsedDefs

                // 3. Resolve active selection
                var initialSelection: [String: String] = [:]
                if let activeVariant = parsedVariants.first(where: { $0.productId == currentProductId }) {
                    initialSelection = activeVariant.selectedOptions
                    self.currentVariant = activeVariant
                } else if let accessoryOpts = accessory.selectedOptions {
                    for (k, v) in accessoryOpts {
                        initialSelection[k.lowercased()] = v.lowercased()
                    }
                }

                // Fill any missing option axes with default / first values
                for def in parsedDefs {
                    if initialSelection[def.id] == nil, let firstVal = def.values.first?.id {
                        initialSelection[def.id] = firstVal
                    }
                }
                self.selectedOptions = initialSelection

                // Update currentVariant if still nil
                if self.currentVariant == nil {
                    self.currentVariant = self.findVariant(matching: initialSelection)
                }

                // Phase determination: if variants > 1 or optionDefinitions has choices, loaded; else empty
                let totalOptionChoices = parsedDefs.reduce(0) { $0 + $1.values.count }
                if self.variants.count > 1 || totalOptionChoices > 1 {
                    self.variantsPhase = .loaded
                } else {
                    self.variantsPhase = .empty
                }
            }
        }
    }

    func retryVariants() {
        loadVariants()
    }

    /// Finds a sellable variant matching the provided option dictionary.
    func findVariant(matching options: [String: String]) -> PPAccessoryViewerVariant? {
        guard !options.isEmpty else { return nil }
        return variants.first { variant in
            guard !variant.isArchived else { return false }
            for (optId, valId) in options {
                if variant.selectedOptions[optId] != valId {
                    return false
                }
            }
            return true
        }
    }

    /// Evaluates dynamic compatibility & stock status for an option value.
    func status(
        forOptionValue value: PPAccessoryViewerOptionValue,
        inOption option: PPAccessoryViewerOptionDefinition
    ) -> PPAccessoryViewerOptionValueStatus {
        let optId = option.id.lowercased()
        let valId = value.id.lowercased()

        // 1. Is this value currently selected?
        if selectedOptions[optId] == valId {
            return .selected
        }

        // 2. Build candidate selection keeping other axes fixed
        var candidate = selectedOptions
        candidate[optId] = valId

        // 3. Find if a variant matches this combination
        if let match = findVariant(matching: candidate) {
            if match.productId == accessory?.accessoryID {
                return (snapshot?.quantity ?? 0) > 0 ? .available : .outOfStock
            }
            return .available
        }

        // 4. If no exact match with other current choices, check if this value exists anywhere
        let existsAnywhere = variants.contains { variant in
            !variant.isArchived && variant.selectedOptions[optId] == valId
        }

        return existsAnywhere ? .incompatible : .incompatible
    }

    /// User taps an option value (e.g. Size = "Large" or Color = "Red").
    func selectOptionValue(optionId: String, valueId: String) {
        guard switchingVariantProductId == nil else { return }
        guard cartPhase != .processing, checkoutPhase != .preparingCart else {
            bannerMessage = PPAccessoryViewerL10n.text("accessory_view_colors_busy")
            return
        }

        let cleanOptId = optionId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanValId = valueId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // If already selected, do nothing
        if selectedOptions[cleanOptId] == cleanValId {
            return
        }

        var target = selectedOptions
        target[cleanOptId] = cleanValId

        // Look for exact matching variant
        if let exactMatch = findVariant(matching: target) {
            selectedOptions = target
            selectVariant(exactMatch)
            return
        }

        // Look for alternative variant having this option value
        let alternatives = variants.filter { variant in
            !variant.isArchived && variant.selectedOptions[cleanOptId] == cleanValId
        }

        if let bestAlternative = alternatives.first {
            selectedOptions = bestAlternative.selectedOptions
            selectVariant(bestAlternative)
            return
        }

        // Incompatible / unavailable combination
        bannerMessage = PPAccessoryViewerL10n.text("accessory_view_option_incompatible")
        UIAccessibility.post(
            notification: .announcement,
            argument: bannerMessage
        )
    }

    /// Switches the screen to another variant of the same family, in place.
    ///
    /// The variant's own `petAccessories` document becomes the product being viewed, so
    /// price, stock, images, cart state and the add-to-cart target all follow from it
    /// with no special-casing anywhere else.
    func selectVariant(_ variant: PPAccessoryViewerVariant) {
        guard switchingVariantProductId == nil else { return }
        guard variant.productId != accessory?.accessoryID else {
            currentVariant = variant
            return
        }
        guard cartPhase != .processing, checkoutPhase != .preparingCart else {
            // Never move the ground under an in-flight purchase: the mutation was
            // authorized against the variant on screen.
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_colors_busy"
            )
            return
        }

        switchingVariantProductId = variant.productId
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()

        PPAccessoryViewerLegacyBridge.fetchAccessory(
            accessoryID: variant.productId
        ) { [weak self] resolved, error in
            Task { @MainActor in
                guard let self else { return }
                self.switchingVariantProductId = nil

                guard let resolved, error == nil else {
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        error == nil
                            ? "accessory_view_colors_missing"
                            : "accessory_view_colors_failed"
                    )
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: self.bannerMessage
                    )
                    return
                }

                self.apply(variantAccessory: resolved, variant: variant)
            }
        }
    }

    /// Rebinds every piece of per-product state to a newly selected variant.
    private func apply(
        variantAccessory: PetAccessory,
        variant: PPAccessoryViewerVariant
    ) {
        let previousOwnerID = accessory?.ownerID
        let nextSnapshot = PPAccessoryViewerSnapshot(accessory: variantAccessory)

        accessory = variantAccessory
        snapshot = nextSnapshot
        currentVariant = variant
        if !variant.selectedOptions.isEmpty {
            selectedOptions = variant.selectedOptions
        }
        livePhase = nextSnapshot.isUnavailable ? .deleted : .current

        // Quantity is per-product. Carrying "3" across a variant change would silently
        // request three of a variant that may only have one in stock.
        quantity = 1
        preparedCheckoutCartQuantity = nil
        checkoutPhase = .ready
        cartPhase = .ready
        successResetTask?.cancel()
        stockNotificationPhase = .idle

        refreshCartState()

        // Favorites are per-product, so this must be re-read. Owner and suggestions are
        // provider-scoped and identical across a family in practice.
        loadFavorite()
        if previousOwnerID != variantAccessory.ownerID {
            loadOwner()
            loadSuggestions()
        }

        // Re-point the live listener at the new document
        startLiveListener()

        let urls = nextSnapshot.media.compactMap(\.imageURL)
        PPAccessoryViewerLegacyBridge.prefetch(urls: urls)

        if nextSnapshot.isUnavailable {
            bannerMessage = PPAccessoryViewerL10n.text(
                "accessory_view_colors_unavailable"
            )
        } else {
            bannerMessage = nil
        }

        let optionSummary: String = {
            if !optionDefinitions.isEmpty {
                let parts = optionDefinitions.compactMap { def -> String? in
                    guard let valId = selectedOptions[def.id],
                          let val = def.values.first(where: { $0.id == valId }) else { return nil }
                    return "\(def.localizedName): \(val.localizedName)"
                }
                if !parts.isEmpty {
                    return parts.joined(separator: "، ")
                }
            }
            return variant.name.isEmpty ? variant.id : variant.name
        }()

        UIAccessibility.post(
            notification: .announcement,
            argument: PPAccessoryViewerL10n.formatted(
                "accessory_view_colors_selected_format",
                optionSummary
            )
        )
    }

    private func loadFavorite() {        guard let accessory else { return }
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
