import SwiftUI
import UIKit

struct PPPetAdRemoteImageView: View {
    let urlString: String?
    let blurHash: String?
    let contentMode: ContentMode
    let accessibilityLabel: String

    @StateObject private var loader = PPPetAdImageLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.ppForeground

            switch loader.state {
            case .idle:
                placeholder
            case let .loading(image):
                if let image {
                    rendered(image: image)
                        .transition(.opacity)
                } else {
                    placeholder
                }
                ProgressView()
                    .tint(Color.ppPrimary)
                    .accessibilityLabel(
                        PPPetAdLocalization.text(
                            "loading_images",
                            fallback: "Loading image"
                        )
                    )
            case let .loaded(image):
                rendered(image: image)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 1.015)
                            )
                    )
            case .failed:
                Button {
                    loader.retry(blurHash: blurHash)
                } label: {
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
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    PPPetAdLocalization.text(
                        "load_error_retry",
                        fallback: "Double-tap to retry loading this image."
                    )
                )
            }
        }
        .clipped()
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.24),
            value: imageStateIdentity
        )
        .onAppear {
            loader.load(urlString: urlString, blurHash: blurHash)
        }
        .adOnChange(of: urlString) { value in
            loader.load(urlString: value, blurHash: blurHash)
        }
        .onDisappear {
            loader.cancel()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ppPrimary.opacity(0.14),
                    Color.ppForeground,
                    Color.ppPrimaryShiner.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "pawprint.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.ppPrimary.opacity(0.30))
        }
    }

    @ViewBuilder
    private func rendered(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private var imageStateIdentity: Int {
        switch loader.state {
        case .idle: return 0
        case .loading: return 1
        case .loaded: return 2
        case .failed: return 3
        }
    }
}
