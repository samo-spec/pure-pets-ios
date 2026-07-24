import SwiftUI
import UIKit

struct PPPetAdHeroGallery: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let collapseProgress: CGFloat
    let onOpen: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var footerVisibility: CGFloat {
        max(0, 1 - (collapseProgress * 1.55))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if items.isEmpty {
                emptyHero
            } else {
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
            }

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.06),
                    .black.opacity(0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.45 + (footerVisibility * 0.55))
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    .black.opacity(0.48),
                    .black.opacity(0.12),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            if items.count > 1 {
                galleryFooter
                    .padding(.horizontal, PPSpace.screenMargin)
                    .padding(.bottom, PPSpace.xl)
                    .opacity(footerVisibility)
                    .scaleEffect(
                        reduceMotion
                            ? 1
                            : 0.96 + (footerVisibility * 0.04)
                    )
                    .allowsHitTesting(footerVisibility > 0.35)
                    .accessibilityHidden(footerVisibility < 0.35)
            }
        }
        .background(Color.black)
        .clipped()
        .onChange(of: selection) { value in
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

    @ViewBuilder
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
                    .fill(Color.clear)
                    .frame(width: 66, height: 66)
                    .ppGlassSurface(
                        in: Circle(),
                        tint: Color.black.opacity(0.14),
                        fallback: Color.black.opacity(0.82)
                    )
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
                    .shadow(
                        color: .black.opacity(0.22),
                        radius: 16,
                        y: 8
                    )
                    .opacity(max(0, 1 - (collapseProgress * 1.8)))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen(index)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(
            PPPetAdLocalization.text(
                "pet_ad_viewer_open_media_hint",
                fallback: "Opens the full-screen media viewer"
            )
        )
    }

    private var galleryFooter: some View {
        HStack(spacing: PPSpace.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PPSpace.sm) {
                    ForEach(Array(items.enumerated()), id: \.element.id) {
                        index,
                        item in
                        Button {
                            if reduceMotion {
                                selection = index
                            } else {
                                withAnimation(PPPetAdViewerMotion.content) {
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
                            .frame(width: 46, height: 46)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                                .stroke(
                                    index == selection
                                        ? Color.white
                                        : Color.white.opacity(0.25),
                                    lineWidth: index == selection ? 2 : 0.75
                                )
                            }
                            .scaleEffect(index == selection ? 1 : 0.92)
                        }
                        .buttonStyle(
                            PPPetAdPressButtonStyle(pressedScale: 0.90)
                        )
                        .accessibilityValue(
                            index == selection
                                ? PPPetAdLocalization.text(
                                    "Selected",
                                    fallback: "Selected"
                                )
                                : ""
                        )
                    }
                }
            }

            Text("\(selection + 1) / \(items.count)")
                .font(
                    .custom(
                        "Beiruti-Bold",
                        size: 13,
                        relativeTo: .caption
                    )
                )
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, PPSpace.md)
                .frame(minHeight: 38)
                .ppGlassSurface(
                    in: Capsule(),
                    tint: Color.black.opacity(0.12),
                    fallback: Color.black.opacity(0.82)
                )
                .accessibilityLabel(
                    "\(selection + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
                )
        }
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
                .font(
                    .custom(
                        "Beiruti-Bold",
                        size: 17,
                        relativeTo: .headline
                    )
                )
            }
            .foregroundStyle(.white.opacity(0.92))
            .opacity(max(0, 1 - (collapseProgress * 1.35)))
        }
        .accessibilityElement(children: .combine)
    }

    private func mediaAccessibilityLabel(index: Int) -> String {
        let type =
            items[index].isVideo
            ? PPPetAdLocalization.text("Video", fallback: "Video")
            : PPPetAdLocalization.text("Photo", fallback: "Photo")
        return
            "\(type) \(index + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
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
