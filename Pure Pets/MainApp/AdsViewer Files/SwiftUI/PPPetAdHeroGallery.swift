import SwiftUI
import UIKit

/// Full-bleed cinematic gallery: paged media, dual-phase legibility scrims, and
/// a floating frosted-glass thumbnail rail with spring selection dynamics.
///
/// Tapping any page opens the fullscreen media viewer. Neighboring pages
/// are prefetched so swiping never displays a placeholder.
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
                floatingThumbnailRail
                    .padding(.horizontal, 20)
                    .padding(.bottom, PPSpace.xxl)
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
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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
                            .stroke(.white.opacity(0.36), lineWidth: 0.75)
                    }
                    .shadow(
                        color: .black.opacity(0.28),
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

    // MARK: - Scrims & Floating Thumbnail Rail

    private var topScrim: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.52),
                .black.opacity(0.12),
                .clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bottomScrim: some View {
        LinearGradient(
            colors: [
                .clear,
                .black.opacity(0.06),
                .black.opacity(0.56)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Premium frosted glass floating container for thumbnail items.
    private var floatingThumbnailRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm + 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        thumbnailButton(item, index: index)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, PPSpace.md)
                .padding(.vertical, PPSpace.sm - 2)
            }
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
            .adOnChange(of: selection) { value in
                withAnimation(.snappy) {
                    proxy.scrollTo(items[value].id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: 74)
        .accessibilityLabel(
            PPPetAdLocalization.text(
                "pet_ad_viewer_gallery_thumbnails",
                fallback: "Photo thumbnails"
            )
        )
    }

    private func thumbnailButton(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        let isSelected = index == selection

        return Button {
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
                accessibilityLabel: mediaAccessibilityLabel(index: index)
            )
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected ? Color.white : Color.white.opacity(0.24),
                        lineWidth: isSelected ? 2.25 : 0.75
                    )
            }
            .scaleEffect(isSelected ? 1.06 : 0.94)
            .shadow(
                color: isSelected ? .black.opacity(0.35) : .clear,
                radius: 6,
                y: 3
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.92))
    }

    private var emptyHero: some View {
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
                .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
            }
            .foregroundStyle(.white.opacity(0.92))
        }
        .accessibilityElement(children: .combine)
    }

    private func mediaAccessibilityLabel(index: Int) -> String {
        let type = items[index].isVideo
            ? PPPetAdLocalization.text("Video", fallback: "Video")
            : PPPetAdLocalization.text("Photo", fallback: "Photo")
        return "\(type) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
    }

    private func prefetchNeighbors(around index: Int) {
        guard !items.isEmpty else { return }
        let indexes = [index - 1, index, index + 1]
        let urls = indexes.compactMap { value -> String? in
            guard items.indices.contains(value) else { return nil }
            return items[value].imageURL
        }
        PPPetAdViewerLegacyBridge.prefetch(urls: urls)
    }
}
