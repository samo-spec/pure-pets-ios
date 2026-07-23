import Foundation

struct PPPetAdMediaItem: Identifiable, Equatable {
    let id: String
    let imageURL: String?
    let videoURL: String?
    let blurHash: String?
    let isVideo: Bool

    static func items(from ad: PetAd) -> [PPPetAdMediaItem] {
        let mappedItems = ad.imageItems.enumerated().compactMap { index, item in
            makeItem(from: item, index: index)
        }
        if !mappedItems.isEmpty {
            return mappedItems
        }

        return (ad.imageURLs ?? []).enumerated().compactMap { index, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return PPPetAdMediaItem(
                id: "\(index)-\(trimmed)",
                imageURL: trimmed,
                videoURL: nil,
                blurHash: ad.blurHash,
                isVideo: false
            )
        }
    }

    private static func makeItem(
        from item: PetImageItem,
        index: Int
    ) -> PPPetAdMediaItem? {
        let rawURL = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawVideoURL =
            item.videoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mediaType = item.mediaType.lowercased()
        let isVideo = item.isVideoMedia || mediaType.contains("video")
        let metadata = item.mediaMetadata ?? [:]
        let thumbnail =
            (metadata["thumbnail_url"] as? String) ??
            (metadata["thumbnailURL"] as? String) ??
            (metadata["thumbnailUrl"] as? String) ??
            (metadata["thumbnail"] as? String)
        let cleanThumbnail =
            thumbnail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedVideoURL: String? = {
            guard isVideo else { return nil }
            if let rawVideoURL, !rawVideoURL.isEmpty {
                return rawVideoURL
            }
            return rawURL.isEmpty ? nil : rawURL
        }()
        let resolvedImageURL: String? = {
            guard isVideo else {
                return rawURL.isEmpty ? nil : rawURL
            }
            if let cleanThumbnail, !cleanThumbnail.isEmpty {
                return cleanThumbnail
            }
            if !rawURL.isEmpty, rawURL != resolvedVideoURL {
                return rawURL
            }
            return nil
        }()

        guard resolvedImageURL != nil || resolvedVideoURL != nil else {
            return nil
        }

        return PPPetAdMediaItem(
            id: "\(index)-\(resolvedVideoURL ?? resolvedImageURL ?? rawURL)",
            imageURL: resolvedImageURL,
            videoURL: resolvedVideoURL,
            blurHash: item.blurHash,
            isVideo: isVideo
        )
    }
}
