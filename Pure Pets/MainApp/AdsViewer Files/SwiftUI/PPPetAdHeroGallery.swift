import SwiftUI
import UIKit

/// Full-bleed cinematic gallery: paged media, a frosted page counter, and
/// a leading-edge thumbnail rail with a spring-loaded selection ring.
///
/// Tapping any page opens the fullscreen media viewer. Neighboring pages
/// are prefetched so swiping never shows a placeholder.
struct PPPetAdHeroGallery: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let onOpen: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            if items.isEmpty {
                emptyHero
            } else {
                pager
            }

            topScrim
            bottomScrim

            if items.count > 1 {
                bottomThumbnailRail
                    .padding(.bottom, PPSpace.xxxl)
            }
        }
        .background(Color.black)
        .adOnChange(of: selection) { value in
            guard items.indices.contains(value) else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            prefetchNeighbors(around: value)
        }
        .onAppear {
            selection = min(max(selection, 0), max(items.count - 1, 0))
            prefetchNeighbors(around: selection)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Pager

    private var pager: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) {
                index,
                item in
                mediaPage(item, index: index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_gallery",
                fallback: "Pet photos"
            )
        )
        .accessibilityAdjustableAction { direction in
            let last = max(items.count - 1, 0)
            switch direction {
            case .increment:
                selection = min(selection + 1, last)
            case .decrement:
                selection = max(selection - 1, 0)
            @unknown default:
                break
            }
        }
    }

    private func mediaPage(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        ZStack {
            PPPetAdRemoteImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                contentMode: .fill,
                accessibilityLabel: mediaAccessibilityLabel(index: index)
            )

            if item.isVideo {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.34), lineWidth: 0.75)
                    }
                    .shadow(
                        color: .black.opacity(0.26),
                        radius: 18,
                        y: 8
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(index)
        }
    }

    // MARK: - Thumbnail rail

    var bottomThumbnailRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.md) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        thumbnailButton(item, index: index)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, PPSpace.xs)
            }
            .frame(maxHeight: 76)
            .adOnChange(of: selection) { value in
                withAnimation(.snappy) {
                    proxy.scrollTo(items[value].id, anchor: .center)
                }
            }
        }
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_gallery_thumbnails",
                fallback: "Photo thumbnails"
            )
        )
    }

    // MARK: - Thumbnail button

    func thumbnailButton(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        Button {
            if reduceMotion {
                selection = index
            } else {
                withAnimation(PPPetAdViewerMotion.heroPage) {
                    selection = index
                }
            }
        } label: {
            PPPetAdRemoteImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                contentMode: .fill,
                accessibilityLabel:
                    mediaAccessibilityLabel(index: index)
            )
            .frame(width: 44, height: 44)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    index == selection
                        ? Color.white
                        : Color.white.opacity(0.30),
                    lineWidth: index == selection ? 2 : 0.75
                )
            }
            .brightness(index == selection ? 0.05 : 0)
            .shadow(
                color: index == selection ? .black.opacity(0.3) : .clear,
                radius: 4,
                y: 2
            )
        }
        .buttonStyle(
            PPPetAdPressButtonStyle(pressedScale: 0.90)
        )
    }

    // MARK: - Empty hero

    var emptyHero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.ppPrimaryDarker,
                    Color.ppPrimary,
                    Color.ppPrimaryShiner
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: PPSpace.md) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 54, weight: .semibold))
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_no_media",
                        fallback: "Photos are not available"
                    )
                )
                .font(
                    .custom(
                        "Beiruti-Bold",
                        size: 17,
                        relativeTo: .headline
                    )
                )
            }
            .foregroundStyle(.white.opacity(0.92))
        }
        .accessibilityElement(children: .combine)
    }

    func mediaAccessibilityLabel(index: Int) -> String {
        let type = items[index].isVideo
            ? PPPetAdLocalization.text("Video", fallback: "Video")
            : PPPetAdLocalization.text("Photo", fallback: "Photo")
        return "\(type) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
    }

    func prefetchNeighbors(around index: Int) {
        guard !items.isEmpty else { return }
        let indexes = [index - 1, index, index + 1]
        let urls = indexes.compactMap { value -> String? in
            guard items.indices.contains(value) else { return nil }
            return items[value].imageURL
        }
        PPPetAdViewerLegacyBridge.prefetch(urls: urls)
    }
}

// MARK: - Scrims, footer & states

private extension PPPetAdHeroGallery {
    /// Keeps the navigation chrome legible over bright imagery.
    var topScrim: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.38),
                .black.opacity(0.08),
                .clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Grounds the page counter and thumbnails against light photos.
    var bottomScrim: some View {
        LinearGradient(
            colors: [
                .clear,
                .black.opacity(0.04),
                .black.opacity(0.44)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
