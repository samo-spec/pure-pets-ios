import Vision
import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct PPPetAdHeroGallery: View {
    let items: [PPPetAdMediaItem]
    @Binding var selection: Int
    let interactionState: PPPetAdViewerInteractionState
    let onOpen: (Int) -> Void
    var bottomViewType: PPGarBottomViewType = .thumbRails
    var onFirstImageLoaded: ((UIImage) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let thumbnailSize: CGFloat = 44
    private let thumbnailRailInset: CGFloat = 10

    var body: some View {
        ZStack(alignment: .bottom) {
            gallery
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            contrastLayers

            if items.count > 1 {
                switch bottomViewType {
                case .indicator:
                    PPPetAdGalleryHandoff(
                        interactionState: interactionState
                    ) {
                        pageControl
                            .padding(.horizontal, PPSpace.screenMargin)
                            .padding(.bottom, PPSpace.xxxxl)
                    }
                case .thumbRails:
                    PPPetAdGalleryHandoff(
                        interactionState: interactionState
                    ) {
                        thumbnailFooter
                            .padding(.horizontal, PPSpace.screenMargin)
                            .padding(.bottom, PPSpace.xxxl + PPSpace.xs)
                    }
                case .contactPill:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
        .background(Color.clear)
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
        ZStack(alignment: .center) {
            PPPetAdHeroImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                interactionState: interactionState,
                accessibilityLabel: mediaAccessibilityLabel(index: index),
                onImageLoaded: index == 0 ? onFirstImageLoaded : nil
            )
            .ignoresSafeArea(edges: .top)

            if item.isVideo {
                PPPetAdGalleryHandoff(
                    interactionState: interactionState
                ) {
                    videoPlayIndicator
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        PPPetAdHeroAtmosphere(interactionState: interactionState)
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

            PPPetAdGalleryHandoff(
                interactionState: interactionState
            ) {
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
            }
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

private struct PPPetAdGalleryHandoff<Content: View>: View {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let content: Content

    init(
        interactionState: PPPetAdViewerInteractionState,
        @ViewBuilder content: () -> Content
    ) {
        self.interactionState = interactionState
        self.content = content()
    }

    var body: some View {
        content
            .opacity(Double(interactionState.galleryLensOpacity))
            .offset(
                y: reduceMotion ? 0 : interactionState.galleryLensTranslation
            )
            .scaleEffect(
                reduceMotion
                    ? 1
                    : 0.98 + (0.02 * interactionState.galleryLensOpacity)
            )
            .allowsHitTesting(interactionState.galleryLensOpacity > 0.40)
            .accessibilityHidden(
                !interactionState.galleryLensOwnsAccessibility
            )
    }
}

private struct PPPetAdHeroAtmosphere: View {
    @ObservedObject var interactionState: PPPetAdViewerInteractionState

    var body: some View {
        LinearGradient(
            stops: [
                .init(
                    color: Color.ppBackground.opacity(
                        Double(0.08 + (0.06 * interactionState.progress))
                    ),
                    location: 0
                ),
                .init(color: Color.clear, location: 0.42),
                .init(
                    color: Color.ppBackground.opacity(
                        Double(0.10 + (0.12 * interactionState.progress))
                    ),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PPPetAdHeroImageView: View {
    let urlString: String?
    let blurHash: String?
    @ObservedObject var interactionState: PPPetAdViewerInteractionState
    let accessibilityLabel: String
    var onImageLoaded: ((UIImage) -> Void)? = nil

    @StateObject private var loader = PPPetAdImageLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        urlString: String?,
        blurHash: String?,
        interactionState: PPPetAdViewerInteractionState,
        accessibilityLabel: String,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.urlString = urlString
        self.blurHash = blurHash
        _interactionState = ObservedObject(wrappedValue: interactionState)
        self.accessibilityLabel = accessibilityLabel
        self.onImageLoaded = onImageLoaded
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
        PPPetAdTopAnchoredFillImage(image: image)
            .scaleEffect(
                reduceMotion ? 1 : interactionState.heroScale,
                anchor: .top
            )
            .offset(
                y: reduceMotion ? 0 : interactionState.heroTranslation
            )
            .saturation(Double(interactionState.heroSaturation))
            .opacity(Double(interactionState.focusedHeroOpacity))
            .clipped()
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

// MARK: - Vision Pet Face Focal Detector

final class PPPetFaceFocusDetector {
    static let shared = PPPetFaceFocusDetector()
    private var cache = NSCache<UIImage, NSValue>()

    private init() {
        cache.countLimit = 60
    }

    func detectFocusPoint(for image: UIImage, completion: @escaping (CGPoint) -> Void) {
        if let cached = cache.object(forKey: image) {
            completion(cached.cgPointValue)
            return
        }

        guard let cgImage = image.cgImage else {
            completion(CGPoint(x: 0.5, y: 0.38))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var detectedPoint: CGPoint?

            // Attempt animal body detection (iOS 15+)
            if #available(iOS 15.0, *) {
                let animalRequest = VNRecognizeAnimalsRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([animalRequest])

                if let topObservation = animalRequest.results?.first {
                    let box = topObservation.boundingBox
                    // Vision uses bottom-left origin; convert to top-left for UIKit
                    let focusY = 1.0 - (box.origin.y + box.size.height * 0.75)
                    detectedPoint = CGPoint(x: box.midX, y: focusY)
                }
            }

            // Fallback: human face detection (iOS 11+)
            if detectedPoint == nil {
                let faceRequest = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([faceRequest])

                if let topFace = faceRequest.results?.first {
                    let box = topFace.boundingBox
                    let focusY = 1.0 - (box.origin.y + box.size.height * 0.5)
                    detectedPoint = CGPoint(x: box.midX, y: focusY)
                }
            }

            // Default: upper-third sweet spot
            let finalPoint = detectedPoint ?? CGPoint(x: 0.5, y: 0.38)
            self?.cache.setObject(NSValue(cgPoint: finalPoint), forKey: image)

            DispatchQueue.main.async {
                completion(finalPoint)
            }
        }
    }
}

private struct PPPetAdTopAnchoredFillImage: View {
    let image: UIImage
    @State private var focusPoint = CGPoint(x: 0.5, y: 0.38)

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.size
            let widthScale = proxy.size.width / max(imageSize.width, 1)
            let heightScale = proxy.size.height / max(imageSize.height, 1)
            let scale = max(widthScale, heightScale)
            let renderedW = imageSize.width * scale
            let renderedH = imageSize.height * scale

            // Where the detected focus sits in rendered-pixel space
            let focalX = renderedW * focusPoint.x
            let focalY = renderedH * focusPoint.y

            // Desired: place that focal point at the viewport's visual center
            let rawOffsetX = (proxy.size.width / 2) - focalX
            let rawOffsetY = (proxy.size.height * 0.40) - focalY

            // Clamp so the image always fully covers the viewport
            let clampedX = min(0, max(proxy.size.width - renderedW, rawOffsetX))
            let clampedY = min(0, max(proxy.size.height - renderedH, rawOffsetY))

            Image(uiImage: image)
                .resizable()
                .frame(width: renderedW, height: renderedH)
                .offset(x: clampedX, y: clampedY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            PPPetFaceFocusDetector.shared.detectFocusPoint(for: image) { point in
                withAnimation(.easeOut(duration: 0.28)) {
                    self.focusPoint = point
                }
            }
        }
    }
}
