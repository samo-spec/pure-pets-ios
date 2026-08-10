import SwiftUI
import UIKit

struct PPPetAdRemoteImageView: View {
    let urlString: String?
    let blurHash: String?
    let contentMode: ContentMode
    let accessibilityLabel: String
    let showsRetryOnFailure: Bool
    let cacheKey: String?
    let displaySize: CGSize?
    let usesPetFocus: Bool

    init(
        urlString: String?,
        blurHash: String?,
        contentMode: ContentMode,
        accessibilityLabel: String,
        showsRetryOnFailure: Bool = true,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        usesPetFocus: Bool = false
    ) {
        self.urlString = urlString
        self.blurHash = blurHash
        self.contentMode = contentMode
        self.accessibilityLabel = accessibilityLabel
        self.showsRetryOnFailure = showsRetryOnFailure
        self.cacheKey = cacheKey
        self.displaySize = displaySize
        self.usesPetFocus = usesPetFocus
    }

    var body: some View {
        PPPetAdRemoteImageContent(
            urlString: normalizedURLString,
            blurHash: normalizedBlurHash,
            contentMode: contentMode,
            showsRetryOnFailure: showsRetryOnFailure,
            cacheKey: cacheKey,
            displaySize: displaySize,
            usesPetFocus: usesPetFocus
        )
        .id(contentIdentity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private var normalizedURLString: String? {
        normalized(urlString)
    }

    private var normalizedBlurHash: String? {
        normalized(blurHash)
    }

    private var contentIdentity: String {
        [
            normalizedURLString ?? "invalid",
            normalizedBlurHash ?? "no-blurhash",
            cacheKey ?? "default-cache",
            usesPetFocus ? "focused" : "centered"
        ]
        .joined(separator: "|")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct PPPetAdRemoteImageContent: View {
    let urlString: String?
    let blurHash: String?
    let contentMode: ContentMode
    let showsRetryOnFailure: Bool
    let cacheKey: String?
    let displaySize: CGSize?
    let usesPetFocus: Bool

    @State private var blurHashImage: UIImage?
    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack {
            AppRemoteImage(
                urlString: urlString,
                cacheKey: cacheKey,
                displaySize: displaySize,
                contentMode: contentMode,
                showsRetryAction: showsRetryOnFailure,
                onImageLoaded: { image in
                    loadedImage = image
                }
            ) {
                ZStack {
                    placeholder
                    if let blurHashImage {
                        Image(uiImage: blurHashImage)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    }
                    ProgressView()
                        .tint(Color.ppPrimary)
                        .accessibilityLabel(
                            PPPetAdLocalization.text(
                                "loading_images",
                                fallback: "Loading image"
                            )
                        )
                }
            } failurePlaceholder: {
                if showsRetryOnFailure {
                    VStack(spacing: PPSpace.sm) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 26, weight: .semibold))
                        Text(
                            PPPetAdLocalization.text(
                                "Retry",
                                fallback: "Retry"
                            )
                        )
                        .font(
                            .custom(
                                "Beiruti-Bold",
                                size: 14,
                                relativeTo: .callout
                            )
                        )
                    }
                    .foregroundStyle(Color.ppTextSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                } else {
                    placeholder
                }
            }
            .opacity(usesPetFocus && loadedImage != nil ? 0 : 1)

            if usesPetFocus, let loadedImage {
                PPPetAdTopAnchoredFillImage(image: loadedImage)
            }
        }
        .background(Color.ppForeground)
        .clipped()
        .onAppear {
            decodeBlurHashIfNeeded()
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ppForeground,
                    Color.ppTextTertiary.opacity(0.08),
                    Color.ppForeground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.ppTextTertiary.opacity(0.42))
        }
    }

    private func decodeBlurHashIfNeeded() {
        guard let blurHash else {
            blurHashImage = nil
            return
        }

        PPBlurHashBridge.image(
            from: blurHash,
            size: CGSize(width: 40, height: 40),
            punch: 1
        ) { image in
            blurHashImage = image
        }
    }
}
