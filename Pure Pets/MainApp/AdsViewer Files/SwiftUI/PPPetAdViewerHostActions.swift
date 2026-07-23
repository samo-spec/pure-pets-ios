import UIKit

@MainActor
final class PPPetAdViewerHostActions {
    weak var presenter: UIViewController?

    func close() {
        guard let presenter else { return }

        if let navigation = presenter.navigationController,
           navigation.viewControllers.first !== presenter {
            navigation.popViewController(animated: true)
        } else {
            presenter.dismiss(animated: true)
        }
    }

    func share(ad: PetAd) {
        guard let presenter else { return }
        PPPetAdViewerLegacyBridge.share(ad, from: presenter)
    }

    func requireSignIn() async -> Bool {
        guard let presenter else { return false }
        return await withCheckedContinuation { continuation in
            PPPetAdViewerLegacyBridge.presentSignIn(
                from: presenter
            ) { signedIn in
                continuation.resume(returning: signedIn)
            }
        }
    }

    func call(owner: PPPetAdOwner) {
        guard let presenter else { return }
        PPPetAdViewerLegacyBridge.call(owner.user, from: presenter)
    }

    func openWhatsApp(owner: PPPetAdOwner) {
        guard let presenter else { return }
        PPPetAdViewerLegacyBridge.openWhatsApp(
            for: owner.user,
            from: presenter
        )
    }

    func openChat(owner: PPPetAdOwner) async throws {
        guard let presenter else {
            throw NSError(
                domain: "com.purepets.pet-ad-viewer",
                code: 2001,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        PPPetAdLocalization.text(
                            "pet_ad_viewer_chat_failed",
                            fallback:
                                "The chat could not be opened."
                        )
                ]
            )
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PPPetAdViewerLegacyBridge.openChat(
                for: owner.user,
                from: presenter
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func open(accessory: PetAccessory) {
        guard let presenter else { return }
        PPPetAdViewerLegacyBridge.openAccessory(
            accessory,
            from: presenter
        )
    }
}
