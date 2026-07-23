import SwiftUI
import UIKit

/// Cinematic full-bleed gallery: paged media, dual-phase legibility scrims,
/// a frosted page counter, and a floating thumbnail rail where every tile
/// is identical and selection is conveyed by border + light — never scale.
///
/// The image sells the listing. Everything else recedes.
struct PPPetAdHeroGallery: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let onOpen: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            if items.isEmpty {
                emptyHero
            } else {
                pager
            }

            topScrim
            bottomScrim

            if items.count > 1 {
                thumbnailRail
                    .padding(.horizontal, PPSpace.base)
                    .padding(.bottom, PPSpace.sm)
            }
        }
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
            PPPetAdLocalization.text("pet_ad_viewer_gallery", fallback: "Pet photos")
        )
        .accessibilityAdjustableAction { direction in
            let last = max(items.count - 1, 0)
            switch direction {
            case .increment: selection = min(selection + 1, last)
            case .decrement: selection = max(selection - 1, 0)
            @unknown default: break
            }
        }
    }

    private func mediaPage(_ item: PPPetAdMediaItem, index: Int) -> some View {
        ZStack {
            PPPetAdRemoteImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                contentMode: .fill,
                accessibilityLabel: mediaAccessibilityLabel(index: index)
            )

            if item.isVideo {
                videoBadge
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen(index) }
    }

    private var videoBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 2)
        }
        .overlay {
            Circle().stroke(.white.opacity(0.34), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
        .accessibilityHidden(true)
    }

    // MARK: - Page counter

    private var pageCounter: some View {
        HStack(spacing: PPSpace.xs) {
            Text("\(selection + 1)")
                .font(PPPetAdTypography.footnoteBold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .modifier(PPNumericTransition(value: selection))
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selection)

            Text(PPPetAdLocalization.text("pet_ad_viewer_page_of", fallback: "/"))
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(.white.opacity(0.55))

            Text("\(items.count)")
                .font(PPPetAdTypography.footnote)
                .foregroundStyle(.white.opacity(0.78))
                .monospacedDigit()
        }
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.sm - 2)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.12), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(PPPetAdLocalization.text("Photo", fallback: "Photo")) \(selection + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
        )
    }

    // MARK: - Thumbnail rail

    private var thumbnailRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm + 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        thumbnailButton(item, index: index)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, PPSpace.md)
                .padding(.vertical, PPSpace.xs + 2)
            }
            .frame(height: 84)
            .adOnChange(of: selection) { value in
                guard items.indices.contains(value) else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                    proxy.scrollTo(items[value].id, anchor: .center)
                }
            }
        }
        .accessibilityLabel(
            PPPetAdLocalization.text("pet_ad_viewer_gallery_thumbnails", fallback: "Photo thumbnails")
        )
    }

    private func thumbnailButton(_ item: PPPetAdMediaItem, index: Int) -> some View {
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
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.white : Color.white.opacity(0.22),
                        lineWidth: isSelected ? 2 : 0.75
                    )
            }
            .brightness(isSelected ? 0.06 : 0)
            .shadow(color: isSelected ? .black.opacity(0.32) : .clear, radius: 5, y: 2)
        }
        .buttonStyle(PPPetAdPressButtonStyle(pressedScale: 0.94))
        .accessibilityLabel(mediaAccessibilityLabel(index: index))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Empty hero

    private var emptyHero: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ppPrimaryDarker, Color.ppPrimary, Color.ppPrimaryShiner],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: PPSpace.md) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 52, weight: .semibold))
                Text(PPPetAdLocalization.text("pet_ad_viewer_no_media", fallback: "Photos are not available"))
                    .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
            }
            .foregroundStyle(.white.opacity(0.92))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Scrims

    private var topScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.36), .black.opacity(0.08), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bottomScrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.04), .black.opacity(0.42)],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func mediaAccessibilityLabel(index: Int) -> String {
        let type = items[index].isVideo
            ? PPPetAdLocalization.text("Video", fallback: "Video")
            : PPPetAdLocalization.text("Photo", fallback: "Photo")
        return "\(type) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
    }

    private func prefetchNeighbors(around index: Int) {
        guard !items.isEmpty else { return }
        let urls = [index - 1, index, index + 1].compactMap { value -> String? in
            guard items.indices.contains(value) else { return nil }
            return items[value].imageURL
        }
        PPPetAdViewerLegacyBridge.prefetch(urls: urls)
    }
}

// MARK: - Numeric transition (iOS 16+ availability gate)

private struct PPNumericTransition: ViewModifier {
    let value: Int

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.contentTransition(.numericText())
        } else {
            content
        }
    }
}
