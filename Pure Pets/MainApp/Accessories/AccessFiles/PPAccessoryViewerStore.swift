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
    @Published private(set) var quantity = 1
    @Published private(set) var cartQuantity = 0
    @Published private(set) var cartItemsCount = 0
    @Published private(set) var remainingStock = 0
    @Published private(set) var tideSuccessToken = 0
    @Published private(set) var bannerMessage: String?

    private let accessory: PetAccessory?
    private weak var presenter: UIViewController?
    private var didLoad = false
    private var successResetTask: Task<Void, Never>?

    init(accessory: PetAccessory?, presenter: UIViewController) {
        self.accessory = accessory
        self.presenter = presenter
    }

    deinit {
        successResetTask?.cancel()
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
    }

    func retryOwner() {
        loadOwner()
    }

    func retrySuggestions() {
        loadSuggestions()
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
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    func decrementQuantity() {
        guard cartPhase != .processing, quantity > 1 else { return }
        quantity -= 1
        PPAccessoryViewerLegacyBridge.playSelectionFeedback()
    }

    func addToCart() {
        guard let accessory,
              let snapshot,
              snapshot.showsCart,
              !snapshot.isUnavailable,
              remainingStock > 0,
              cartPhase != .processing,
              let presenter else {
            cartPhase = .failed
            return
        }

        successResetTask?.cancel()
        cartPhase = .processing
        PPAccessoryViewerLegacyBridge.addToCart(
            accessory,
            quantity: quantity,
            from: presenter
        ) { [weak self] result, _, cartQuantity, remainingStock in
            guard let self else { return }
            self.cartQuantity = cartQuantity
            self.cartItemsCount =
                PPAccessoryViewerLegacyBridge.cartItemsCount()
            self.remainingStock = remainingStock

            switch result {
            case .success:
                self.cartPhase = .success
                self.tideSuccessToken += 1
                self.quantity = 1
                self.scheduleSuccessReset()
            case .cancelled, .authenticationRequired:
                self.cartPhase = .ready
            case .offline, .outOfStock, .unavailable, .failed:
                self.cartPhase = .failed
                if result == .unavailable || result == .failed {
                    self.bannerMessage = PPAccessoryViewerL10n.text(
                        "accessory_view_add_failed"
                    )
                }
                self.scheduleFailureReset()
            @unknown default:
                self.cartPhase = .failed
                self.scheduleFailureReset()
            }
        }
    }

    func toggleFavorite() {
        guard let accessory, favoritePhase != .loading else { return }
        guard PPAccessoryViewerLegacyBridge.isSignedIn() else {
            guard let presenter else { return }
            PPAccessoryViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { [weak self] signedIn in
                if signedIn {
                    self?.loadFavorite()
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
            guard let self else { return }
            if let user {
                self.owner = PPAccessoryViewerOwner(user: user)
                self.ownerPhase = .loaded
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

    private func loadSuggestions() {
        guard let accessory else { return }
        suggestionsPhase = .loading
        PPAccessoryViewerLegacyBridge.fetchSuggestions(
            for: accessory
        ) { [weak self] items, sameProvider, error in
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

    private func scheduleSuccessReset() {
        successResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
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
}
