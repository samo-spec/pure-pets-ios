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

    @State private var blurHashImage: UIImage?

    init(
        urlString: String?,
        blurHash: String?,
        contentMode: ContentMode,
        accessibilityLabel: String,
        showsRetryOnFailure: Bool = true,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil
    ) {
        self.urlString = urlString
        self.blurHash = blurHash
        self.contentMode = contentMode
        self.accessibilityLabel = accessibilityLabel
        self.showsRetryOnFailure = showsRetryOnFailure
        self.cacheKey = cacheKey
        self.displaySize = displaySize
    }

    var body: some View {
        AppRemoteImage(
            urlString: urlString,
            cacheKey: cacheKey,
            displaySize: displaySize,
            contentMode: contentMode,
            showsRetryAction: showsRetryOnFailure
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
        .background(Color.ppForeground)
        .clipped()
        .onAppear {
            decodeBlurHashIfNeeded()
        }
        .onChange(of: blurHash) { _ in
            decodeBlurHashIfNeeded()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
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
        let normalizedHash = blurHash?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let normalizedHash, !normalizedHash.isEmpty else {
            blurHashImage = nil
            return
        }
        PPBlurHashBridge.image(
            from: normalizedHash,
            size: CGSize(width: 40, height: 40),
            punch: 1
        ) { image in
            guard normalizedHash == blurHash?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) else {
                return
            }
            blurHashImage = image
        }
    }
}
