import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct PPPetAdHeroGallery: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    @ObservedObject var scrollState: PPPetAdHeroScrollVisualState
    let onOpen: (Int) -> Void
    var bottomViewType: PPGarBottomViewType = .thumbRails
    var onFirstImageLoaded: ((UIImage) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let thumbnailSize: CGFloat = 44
    private let thumbnailRailInset: CGFloat = 10

    private var expandedChromeOpacity: CGFloat {
        max(0, 1 - (scrollState.collapseProgress * 1.7))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            gallery
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            contrastLayers

            if items.count > 1 {
                switch bottomViewType {
                case .indicator:
                    pageControl
                        .padding(.horizontal, PPSpace.screenMargin)
                        .padding(.bottom, 44)
                        .opacity(expandedChromeOpacity)
                        .scaleEffect(
                            reduceMotion
                                ? 1
                                : 0.98 + (expandedChromeOpacity * 0.02)
                        )
                        .allowsHitTesting(expandedChromeOpacity > 0.4)
                        .accessibilityHidden(expandedChromeOpacity < 0.4)
                case .thumbRails:
                    thumbnailFooter
                        .padding(.horizontal, PPSpace.screenMargin)
                        .padding(.bottom, 14)
                        .opacity(expandedChromeOpacity)
                        .scaleEffect(
                            reduceMotion
                                ? 1
                                : 0.98 + (expandedChromeOpacity * 0.02)
                        )
                        .allowsHitTesting(expandedChromeOpacity > 0.4)
                        .accessibilityHidden(expandedChromeOpacity < 0.4)
                case .contactPill:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
        .background(Color.clear)
        .ignoresSafeArea(edges: .top)
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
    private var gallery: some View {
        if items.isEmpty {
            emptyHero
                .ignoresSafeArea(edges: .top)
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
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func mediaPage(
        _ item: PPPetAdMediaItem,
        index: Int
    ) -> some View {
        ZStack(alignment: .top) {
            PPPetAdHeroImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                collapseProgress: scrollState.collapseProgress,
                accessibilityLabel: mediaAccessibilityLabel(index: index),
                onImageLoaded: index == 0 ? onFirstImageLoaded : nil
            )
            .ignoresSafeArea(edges: .top)

            if item.isVideo {
                videoPlayIndicator
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var contrastLayers: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.08),
                Color.clear,
                PPPetAdViewerStyle.heroPeachBottom.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var videoPlayIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 62, height: 62)
            .ppGlassSurface(
                in: Circle(),
                tint: Color.black.opacity(0.16),
                fallback: Color.black.opacity(0.84),
                stroke: Color.white.opacity(0.22)
            )
            .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
            .offset(x: 2)
            .opacity(expandedChromeOpacity)
            .scaleEffect(
                reduceMotion
                    ? 1
                    : 0.94 + (expandedChromeOpacity * 0.06)
            )
            .accessibilityHidden(true)
    }

    private var pageControl: some View {
        HStack(spacing: 6) {
            ForEach(visibleIndicatorRange, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selection
                            ? Color.ppTextPrimary
                            : Color.ppTextPrimary.opacity(0.28)
                    )
                    .frame(
                        width: index == selection ? 18 : 6,
                        height: 6
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : PPPetAdViewerMotion.expansion,
                        value: selection
                    )
            }
        }
        .padding(.horizontal, PPSpace.base)
        .frame(minHeight: 32)
        .background(
            PPPetAdViewerStyle.sheetBackground.opacity(0.90),
            in: Capsule()
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(selection + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
        )
    }

    private var thumbnailFooter: some View {
        HStack(spacing: PPSpace.sm) {
            thumbnailRail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thumbnailRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PPSpace.sm) {
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
                            .frame(width: thumbnailSize, height: thumbnailSize)
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
                                .strokeBorder(
                                    index == selection
                                        ? Color.white
                                        : Color.white.opacity(0.24),
                                    lineWidth: index == selection ? 2 : 0.75
                                )
                            }
                            .opacity(index == selection ? 1 : 0.72)
                        }
                        .buttonStyle(
                            PPPetAdPressButtonStyle(pressedScale: 0.92)
                        )
                        .id(index)
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
                .padding(.horizontal, thumbnailRailInset)
                .padding(.vertical, thumbnailRailInset)
            }
            .frame(width: thumbnailRailWidth, height: thumbnailRailHeight)
            .ppGlassSurface(
                in: RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                ),
                tint: Color.black.opacity(0.20),
                fallback: Color.black.opacity(0.82),
                stroke: Color.white.opacity(0.24)
            )
            .onChange(of: selection) { value in
                guard items.indices.contains(value) else { return }
                if reduceMotion {
                    proxy.scrollTo(value, anchor: .center)
                } else {
                    withAnimation(PPPetAdViewerMotion.content) {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
    }

    private var pageCount: some View {
        Text("\(selection + 1) / \(items.count)")
            .font(PPPetAdTypography.footnoteBold)
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: 52, minHeight: 40)
            .ppGlassSurface(
                in: Capsule(),
                tint: Color.black.opacity(0.20),
                fallback: Color.black.opacity(0.82),
                stroke: Color.white.opacity(0.24)
            )
            .fixedSize()
            .accessibilityLabel(
                "\(selection + 1) \(PPPetAdLocalization.text("of", fallback: "of")) \(items.count)"
            )
    }

    private var thumbnailRailWidth: CGFloat {
        let count = max(items.count, 1)
        let spacing = PPSpace.sm * CGFloat(max(count - 1, 0))
        let neededWidth =
            (thumbnailSize * CGFloat(count)) + spacing + (thumbnailRailInset * 2)
        let maxAllowedWidth = max(0, UIScreen.main.bounds.width - (PPSpace.screenMargin * 2))
        return min(neededWidth, maxAllowedWidth)
    }

    private var thumbnailRailHeight: CGFloat {
        thumbnailSize + (thumbnailRailInset * 2)
    }

    private var emptyHero: some View {
        ZStack {
            Rectangle()
                .fill(PPPetAdViewerStyle.heroPeachTop)
                .ignoresSafeArea(edges: .top)
            LinearGradient(
                colors: [
                    PPPetAdViewerStyle.heroPeachTop,
                    PPPetAdViewerStyle.heroPeachBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 300
            )

            VStack(spacing: PPSpace.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 42, weight: .medium))
                Text(
                    PPPetAdLocalization.text(
                        "pet_ad_viewer_no_media",
                        fallback: "Photos are not available"
                    )
                )
                .font(PPPetAdTypography.headline)
            }
            .foregroundStyle(Color.ppTextSecondary.opacity(0.84))
            .opacity(expandedChromeOpacity)
        }
        .accessibilityElement(children: .combine)
    }

    private var visibleIndicatorRange: Range<Int> {
        guard items.count > 0 else { return 0..<0 }
        if items.count <= 7 {
            return 0..<items.count
        }
        let start = min(max(selection - 3, 0), items.count - 7)
        return start..<(start + 7)
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

private struct PPPetAdHeroImageView: View {
    let urlString: String?
    let blurHash: String?
    let collapseProgress: CGFloat
    let accessibilityLabel: String
    var onImageLoaded: ((UIImage) -> Void)? = nil

    @StateObject private var loader = PPPetAdImageLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fittedImageOpacity: CGFloat {
        max(0, 1 - (collapseProgress * 1.65))
    }

    var body: some View {
        ZStack(alignment: .top) {
            heroPlaceholder

            switch loader.state {
            case .idle:
                EmptyView()
            case let .loading(image):
                if let image {
                    rendered(image)
                }
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(
                        PPPetAdLocalization.text(
                            "loading_images",
                            fallback: "Loading image"
                        )
                    )
            case let .loaded(image):
                rendered(image)
            case .failed:
                retryView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .animation(
            reduceMotion ? nil : Animation.easeOut(duration: 0.24),
            value: imageStateIdentity
        )
        .onAppear {
            loader.load(urlString: urlString, blurHash: blurHash)
        }
        .onChange(of: urlString) { value in
            loader.load(urlString: value, blurHash: blurHash)
        }
        .onChange(of: imageStateIdentity) { _ in
            if case let .loaded(image) = loader.state {
                onImageLoaded?(image)
            }
        }
        .onDisappear {
            loader.cancel()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    private func rendered(_ image: UIImage) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    PPPetAdViewerStyle.heroPeachTop,
                    PPPetAdViewerStyle.heroPeachBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            PPPetAdTopAnchoredFillImage(image: image)
                .scaleEffect(1.18, anchor: .top)
                .saturation(0.70)
                .opacity(0.10)

            LinearGradient(
                colors: [
                    PPPetAdViewerStyle.heroPeachTop.opacity(0.70),
                    PPPetAdViewerStyle.heroPeachBottom.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            PPPetAdTopAnchoredFillImage(image: image)
                .opacity(fittedImageOpacity)
                .scaleEffect(
                    reduceMotion
                        ? 1
                        : 1 + (collapseProgress * 0.012),
                    anchor: .top
                )
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .transition(.opacity)
    }

    private var retryView: some View {
        Button {
            loader.retry(blurHash: blurHash)
        } label: {
            Label(
                PPPetAdLocalization.text("Retry", fallback: "Retry"),
                systemImage: "arrow.clockwise"
            )
            .font(PPPetAdTypography.calloutBold)
            .foregroundStyle(.white)
            .padding(.horizontal, PPSpace.lg)
            .frame(minHeight: 46)
            .ppGlassSurface(
                in: Capsule(),
                tint: Color.black.opacity(0.16),
                fallback: Color.black.opacity(0.84)
            )
        }
        .buttonStyle(PPPetAdPressButtonStyle())
        .accessibilityHint(
            PPPetAdLocalization.text(
                "load_error_retry",
                fallback: "Double-tap to retry loading this image."
            )
        )
    }

    private var heroPlaceholder: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    PPPetAdViewerStyle.heroPeachTop,
                    PPPetAdViewerStyle.heroPeachBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.ppTextSecondary.opacity(0.24))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

private struct PPPetAdTopAnchoredFillImage: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.size
            let widthScale = proxy.size.width / max(imageSize.width, 1)
            let heightScale = proxy.size.height / max(imageSize.height, 1)
            let scale = max(widthScale, heightScale)
            let renderedSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            Image(uiImage: image)
                .resizable()
                .frame(width: renderedSize.width, height: renderedSize.height)
                .position(
                    x: proxy.size.width / 2,
                    y: renderedSize.height / 2
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }
}
