import UIKit
import PurePetsAdShareKit

@MainActor
final class PPPetAdViewerHostActions {
    weak var presenter: UIViewController?

    func close() {
        guard let presenter else { return }

        if let navigation = presenter.navigationController {
            if navigation.topViewController === presenter,
               navigation.viewControllers.count > 1 {
                navigation.popViewController(animated: true)
                return
            }

            if navigation.viewControllers.first === presenter,
               navigation.presentingViewController != nil {
                navigation.dismiss(animated: true)
                return
            }
        }

        if presenter.presentingViewController != nil {
            presenter.dismiss(animated: true)
        }
    }

    func share(
        ad: PetAd,
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        guard let presenter else { return }

        if #available(iOS 17.0, *) {
            do {
                let copy = PPPetAdViewerSharePayloadFactory.copy
                let payload = try PPPetAdViewerSharePayloadFactory.payload(
                    for: ad,
                    copy: copy
                )
                let imageSource =
                    PPPetAdViewerSharePayloadFactory.imageSource(for: ad)
                let presentationPresenter = topPresenter(from: presenter)

                Task { @MainActor [weak presenter] in
                    guard let presenter else {
                        onFailure(PPAdShareError.presentationUnavailable)
                        return
                    }

                    let coordinator = PPAdShareCoordinator(
                        configuration: .purePets
                    )
                    do {
                        try await coordinator.present(
                            payload: payload,
                            imageSource: imageSource,
                            copy: copy,
                            from: presentationPresenter
                        )
                    } catch is CancellationError {
                        return
                    } catch {
                        onFailure(error)
                    }
                }
            } catch {
                onFailure(error)
            }
            return
        }

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

    func openChat(owner: PPPetAdOwner, ad: PetAd) async throws {
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
                ad: ad,
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

    private func topPresenter(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController,
              !presented.isBeingDismissed {
            current = presented
        }
        return current
    }
}

@available(iOS 17.0, *)
private enum PPPetAdViewerSharePayloadFactory {
    static var copy: PPAdShareCopy {
        let languageCode =
            (Language.currentLanguageCode() ?? "ar").lowercased()
        return languageCode.hasPrefix("ar") ? .arabic : .english
    }

    static func payload(
        for ad: PetAd,
        copy: PPAdShareCopy
    ) throws -> PPAdSharePayload {
        let publicID = ad.adID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove(charactersIn: "/")
        guard let encodedID = publicID.addingPercentEncoding(
            withAllowedCharacters: pathAllowed
        ),
        let canonicalURL = URL(
            string: "https://purepets.app/ads/\(encodedID)"
        ) else {
            throw PPAdShareError.invalidCanonicalURL
        }

        let title =
            ad.adTitle?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            ?? ""
        let attributes = [
            PPAdShareAttribute(
                id: "category",
                title: PPPetAdViewerLegacyBridge.categoryName(for: ad)
            ),
            PPAdShareAttribute(
                id: "subcategory",
                title: PPPetAdViewerLegacyBridge.subcategoryName(for: ad)
            ),
            PPAdShareAttribute(
                id: "age",
                title: PPPetAdViewerLegacyBridge.ageText(for: ad)
            ),
            PPAdShareAttribute(
                id: "gender",
                title: ad.genderText
            )
        ]

        return try PPAdSharePayload(
            id: publicID,
            title: title.isEmpty ? copy.fallbackTitle : title,
            formattedPrice: nonEmpty(
                PPPetAdViewerLegacyBridge.formattedPrice(for: ad)
            ),
            location: nonEmpty(
                PPPetAdViewerLegacyBridge.locationName(for: ad)
            ),
            shortDescription: ad.adDescription,
            attributes: attributes,
            imageURL: firstImageURL(for: ad),
            canonicalURL: canonicalURL,
            sellerDisplayName: nonEmpty(ad.ownerName)
        )
    }

    static func imageSource(for ad: PetAd) -> PPAdShareImageSource? {
        guard let images = ad.localImages as? [UIImage],
              let image = images.first else { return nil }
        return .image(image)
    }

    private static func firstImageURL(for ad: PetAd) -> URL? {
        let items: [PPPetAdMediaItem] = PPPetAdMediaItem.items(from: ad)
        guard let imageURL = items.first(where: { !$0.isVideo })?.imageURL else {
            return nil
        }
        return URL(string: imageURL)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? nil : trimmed
    }
}
