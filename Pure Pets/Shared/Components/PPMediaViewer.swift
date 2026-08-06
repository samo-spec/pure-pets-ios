// PPMediaViewer.swift
// Pure Pets
//
// Shared full-screen media viewer with image zoom, video playback,
// swipe paging, drag-to-dismiss, and share support.
// Replaces per-feature viewers (PPPetAdMediaViewerScreen,
// PPAccessoryFullScreenMediaViewer) with one production component.

import AVFoundation
import AVKit
import Combine
import SwiftUI
import UIKit

// MARK: - Public Model

/// A single media item that PPMediaViewer can display.
/// Construct from any domain model (PetAd, PetAccessory, etc.).
struct PPMediaItem: Identifiable, Equatable {
    let id: String
    let imageURL: String?
    let videoURL: String?
    let blurHash: String?
    let isVideo: Bool
}

// MARK: - Public Entry Point

/// Shared full-screen media viewer.
///
/// Present with `.fullScreenCover` and supply an array of `PPMediaItem`.
/// Supports swipe paging, pinch-to-zoom images, AVPlayer video playback,
/// drag-to-dismiss, chrome toggle on tap, and a share action.
///
/// ```swift
/// .fullScreenCover(isPresented: $showViewer) {
///     PPMediaViewer(
///         items: mediaItems,
///         selection: $selectedIndex,
///         onDismiss: { showViewer = false },
///         onShare: { shareCurrentMedia() }
///     )
/// }
/// ```
struct PPMediaViewer: View {
    let items: [PPMediaItem]
    @Binding var selection: Int
    var title: String = ""
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var chromeVisible = true
    @State private var dismissOffset: CGFloat = 0
    @State private var activeImageIsZoomed = false
    @State private var activeImageZoomScale: CGFloat = 1
    @State private var zoomCommand = PPMediaViewerZoomCommand(
        token: 0,
        action: .reset
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                missingMediaState
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
                .offset(y: dismissOffset)
                .opacity(dismissOpacity)
                .simultaneousGesture(dismissDragGesture)
            }

            if chromeVisible {
                chrome
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            selection = min(max(selection, 0), max(items.count - 1, 0))
        }
        .onChange(of: selection) { _ in
            UISelectionFeedbackGenerator().selectionChanged()
            activeImageIsZoomed = false
            activeImageZoomScale = 1
            sendZoomCommand(.reset)
        }
        .onChange(of: items.map(\.id)) { _ in
            selection = min(max(selection, 0), max(items.count - 1, 0))
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Media Page

private extension PPMediaViewer {
    @ViewBuilder
    func mediaPage(
        _ item: PPMediaItem,
        index: Int
    ) -> some View {
        if item.isVideo,
           let raw = item.videoURL,
           let url = URL(string: raw)
        {
            PPMediaViewerVideo(
                url: url,
                isActive: index == selection,
                onSingleTap: toggleChrome
            )
            .accessibilityLabel(mediaAccessibilityLabel(index: index))
            .accessibilityAddTraits(.isImage)
        } else {
            PPMediaViewerZoomableImage(
                item: item,
                accessibilityLabel: mediaAccessibilityLabel(index: index),
                isActive: index == selection,
                zoomCommand: zoomCommand,
                isActiveImageZoomed: $activeImageIsZoomed,
                activeImageZoomScale: $activeImageZoomScale,
                onSingleTap: toggleChrome
            )
        }
    }

    func mediaAccessibilityLabel(index: Int) -> String {
        PPMediaViewerL10n.mediaPositionText(
            current: index + 1,
            total: items.count
        )
    }

    var missingMediaState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
            Text(PPMediaViewerL10n.text(
                "image_gallery_empty",
                fallback: "No image available"
            ))
            .font(.custom("Beiruti-Bold", size: 17, relativeTo: .headline))
        }
        .foregroundStyle(Color.white.opacity(0.64))
        .multilineTextAlignment(.center)
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chrome Overlay

private extension PPMediaViewer {
    var chrome: some View {
        VStack {
            // Top bar
            HStack(spacing: 14) {
                chromeButton(
                    symbol: "xmark",
                    label: PPMediaViewerL10n.text(
                        "pp_media_viewer_close",
                        fallback: "Close"
                    ),
                    action: onDismiss
                )

                Spacer()

                VStack(spacing: 2) {
                    if !title.isEmpty {
                        Text(title)
                            .font(.custom("Beiruti-Bold", size: 13, relativeTo: .caption))
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(PPMediaViewerL10n.counterText(
                        current: items.isEmpty ? 0 : selection + 1,
                        total: items.count
                    ))
                    .font(.custom("Beiruti-Bold", size: 14, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, title.isEmpty ? 0 : 4)
                .frame(minHeight: 44)
                .ppGlassSurface(
                    in: Capsule(),
                    tint: Color.black.opacity(0.14),
                    fallback: Color.black.opacity(0.84),
                    stroke: Color.white.opacity(0.16),
                    lineWidth: 0.8,
                    isInteractive: false
                )
                .contentShape(Capsule())

                chromeButton(
                    symbol: "square.and.arrow.up",
                    label: PPMediaViewerL10n.text(
                        "pp_media_viewer_share",
                        fallback: "Share"
                    ),
                    enabled: !items.isEmpty,
                    action: onShare
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer()

            // Bottom controls
            if items.isEmpty {
                EmptyView()
            } else if let current = currentItem, !current.isVideo {
                zoomControls
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            } else {
                pagingControls
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
        }
    }

    var zoomControls: some View {
        HStack(spacing: 12) {
            pagingButton(
                symbol: "chevron.backward",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_previous",
                    fallback: "Previous"
                ),
                enabled: selection > 0 && !activeImageIsZoomed
            ) {
                selection = max(selection - 1, 0)
            }

            Spacer(minLength: 4)

            chromeButton(
                symbol: "minus.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_out",
                    fallback: "Zoom out"
                ),
                enabled: activeImageZoomScale >
                    PPMediaViewerZoomMetrics.minimum +
                    PPMediaViewerZoomMetrics.epsilon
            ) {
                sendZoomCommand(.zoomOut)
            }

            chromeButton(
                symbol: "1.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_reset_zoom",
                    fallback: "Reset zoom"
                ),
                enabled: activeImageZoomScale >
                    PPMediaViewerZoomMetrics.minimum +
                    PPMediaViewerZoomMetrics.epsilon
            ) {
                sendZoomCommand(.reset)
            }

            chromeButton(
                symbol: "plus.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_in",
                    fallback: "Zoom in"
                ),
                enabled: activeImageZoomScale <
                    PPMediaViewerZoomMetrics.maximum -
                    PPMediaViewerZoomMetrics.epsilon
            ) {
                sendZoomCommand(.zoomIn)
            }

            Spacer(minLength: 4)

            pagingButton(
                symbol: "chevron.forward",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_next",
                    fallback: "Next"
                ),
                enabled: selection < items.count - 1 &&
                    !activeImageIsZoomed
            ) {
                selection = min(selection + 1, items.count - 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    var pagingControls: some View {
        HStack {
            pagingButton(
                symbol: "chevron.backward",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_previous",
                    fallback: "Previous"
                ),
                enabled: selection > 0
            ) {
                selection = max(selection - 1, 0)
            }

            Spacer()

            pagingButton(
                symbol: "chevron.forward",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_next",
                    fallback: "Next"
                ),
                enabled: selection < items.count - 1
            ) {
                selection = min(selection + 1, items.count - 1)
            }
        }
    }

    func chromeButton(
        symbol: String,
        label: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .ppGlassSurface(
                    in: Circle(),
                    tint: Color.black.opacity(0.18),
                    fallback: Color.black.opacity(0.85),
                    stroke: Color.white.opacity(0.20),
                    lineWidth: 0.8,
                    isInteractive: true
                )
                .contentShape(Circle())
        }
        .buttonStyle(PPMediaViewerPressStyle(pressedScale: 0.90))
        .contentShape(Circle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.36)
        .accessibilityLabel(label)
    }

    func pagingButton(
        symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        chromeButton(
            symbol: symbol,
            label: label,
            enabled: enabled,
            action: action
        )
    }
}

// MARK: - Interaction Helpers

private extension PPMediaViewer {
    func toggleChrome() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            chromeVisible.toggle()
        }
    }

    var currentItem: PPMediaItem? {
        guard items.indices.contains(selection) else { return nil }
        return items[selection]
    }

    var dismissOpacity: Double {
        let progress = min(abs(dismissOffset) / 360, 0.45)
        return 1 - progress
    }

    var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !activeImageIsZoomed,
                      abs(value.translation.height) >
                        abs(value.translation.width) * 1.2
                else { return }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                guard !activeImageIsZoomed else {
                    dismissOffset = 0
                    return
                }
                let projected = value.predictedEndTranslation.height
                if abs(value.translation.height) > 120
                    || abs(projected) > 220
                {
                    onDismiss()
                    return
                }
                withAnimation(
                    reduceMotion ? nil : .easeOut(duration: 0.24)
                ) {
                    dismissOffset = 0
                }
            }
    }

    func sendZoomCommand(_ action: PPMediaViewerZoomAction) {
        zoomCommand = PPMediaViewerZoomCommand(
            token: zoomCommand.token + 1,
            action: action
        )
    }
}

// MARK: - Zoomable Image

private enum PPMediaViewerZoomAction: Equatable {
    case zoomIn
    case zoomOut
    case reset
}

private struct PPMediaViewerZoomCommand: Equatable {
    let token: Int
    let action: PPMediaViewerZoomAction
}

private enum PPMediaViewerZoomMetrics {
    static let minimum: CGFloat = 1
    static let maximum: CGFloat = 6
    static let step: CGFloat = 0.75
    static let doubleTap: CGFloat = 2.5
    static let epsilon: CGFloat = 0.01
}

private struct PPMediaViewerZoomableImage: View {
    let item: PPMediaItem
    let accessibilityLabel: String
    let isActive: Bool
    let zoomCommand: PPMediaViewerZoomCommand
    @Binding var isActiveImageZoomed: Bool
    @Binding var activeImageZoomScale: CGFloat
    let onSingleTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PPMediaViewerNativeZoomSurface(
            itemID: item.id,
            imageURL: item.imageURL,
            accessibilityLabel: accessibilityLabel,
            isActive: isActive,
            zoomCommand: zoomCommand,
            reduceMotion: reduceMotion,
            isActiveImageZoomed: $isActiveImageZoomed,
            activeImageZoomScale: $activeImageZoomScale,
            onSingleTap: onSingleTap
        )
    }
}

// MARK: - Native Zoom Bridge

private struct PPMediaViewerNativeZoomSurface: UIViewRepresentable {
    let itemID: String
    let imageURL: String?
    let accessibilityLabel: String
    let isActive: Bool
    let zoomCommand: PPMediaViewerZoomCommand
    let reduceMotion: Bool
    @Binding var isActiveImageZoomed: Bool
    @Binding var activeImageZoomScale: CGFloat
    let onSingleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PPMediaViewerZoomCanvasView {
        let canvas = PPMediaViewerZoomCanvasView()
        context.coordinator.attach(to: canvas)
        canvas.reduceMotion = reduceMotion
        canvas.setLayoutDirection(context.environment.layoutDirection)
        canvas.setActive(isActive)
        canvas.configure(
            itemID: itemID,
            imageURL: imageURL,
            accessibilityLabel: accessibilityLabel
        )
        return canvas
    }

    func updateUIView(
        _ canvas: PPMediaViewerZoomCanvasView,
        context: Context
    ) {
        context.coordinator.parent = self
        canvas.reduceMotion = reduceMotion
        canvas.setLayoutDirection(context.environment.layoutDirection)
        canvas.setActive(isActive)
        canvas.configure(
            itemID: itemID,
            imageURL: imageURL,
            accessibilityLabel: accessibilityLabel
        )

        guard isActive,
              context.coordinator.lastZoomCommandToken != zoomCommand.token
        else { return }
        context.coordinator.lastZoomCommandToken = zoomCommand.token
        canvas.perform(zoomCommand.action)
    }

    static func dismantleUIView(
        _ canvas: PPMediaViewerZoomCanvasView,
        coordinator: Coordinator
    ) {
        canvas.prepareForDismantle()
        canvas.onZoomStateChange = nil
        canvas.scrollView.delegate = nil
    }

    final class Coordinator: NSObject,
        UIScrollViewDelegate,
        UIGestureRecognizerDelegate
    {
        var parent: PPMediaViewerNativeZoomSurface
        var lastZoomCommandToken: Int?
        private weak var canvas: PPMediaViewerZoomCanvasView?

        init(parent: PPMediaViewerNativeZoomSurface) {
            self.parent = parent
        }

        func attach(to canvas: PPMediaViewerZoomCanvasView) {
            self.canvas = canvas
            canvas.scrollView.delegate = self
            canvas.onZoomStateChange = { [weak self] in
                self?.publishZoomState()
            }

            let doubleTap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleDoubleTap(_:))
            )
            doubleTap.numberOfTapsRequired = 2
            doubleTap.delegate = self

            let singleTap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleSingleTap(_:))
            )
            singleTap.numberOfTapsRequired = 1
            singleTap.cancelsTouchesInView = false
            singleTap.require(toFail: doubleTap)
            singleTap.delegate = self

            canvas.addGestureRecognizer(doubleTap)
            canvas.addGestureRecognizer(singleTap)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            canvas?.hasDisplayableImage == true ? canvas?.imageView : nil
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            canvas?.zoomDidChange()
        }

        func scrollViewWillBeginZooming(
            _ scrollView: UIScrollView,
            with view: UIView?
        ) {
            canvas?.zoomWillBegin()
        }

        func scrollViewDidEndZooming(
            _ scrollView: UIScrollView,
            with view: UIView?,
            atScale scale: CGFloat
        ) {
            canvas?.zoomDidChange()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let retryButton = canvas?.retryButton,
                  let touchedView = touch.view else { return true }
            return touchedView !== retryButton &&
                !touchedView.isDescendant(of: retryButton)
        }

        @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onSingleTap()
        }

        @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let canvas else { return }
            let location = recognizer.location(in: canvas.imageView)
            canvas.toggleZoom(around: location)
        }

        private func publishZoomState() {
            guard let canvas else { return }
            let scale = canvas.normalizedZoomScale
            let zoomed = scale >
                PPMediaViewerZoomMetrics.minimum +
                PPMediaViewerZoomMetrics.epsilon

            DispatchQueue.main.async { [weak self] in
                guard let self, self.parent.isActive else { return }
                if self.parent.isActiveImageZoomed != zoomed {
                    self.parent.isActiveImageZoomed = zoomed
                }
                let reachedBoundary = scale <=
                    PPMediaViewerZoomMetrics.minimum +
                    PPMediaViewerZoomMetrics.epsilon ||
                    scale >= PPMediaViewerZoomMetrics.maximum -
                    PPMediaViewerZoomMetrics.epsilon
                if reachedBoundary ||
                    abs(self.parent.activeImageZoomScale - scale) > 0.05 {
                    self.parent.activeImageZoomScale = scale
                }
            }
        }
    }
}

// MARK: - Native Zoom Canvas

private final class PPMediaViewerAccessibleImageView: UIImageView {
    var onAccessibilityIncrement: (() -> Void)?
    var onAccessibilityDecrement: (() -> Void)?

    override func accessibilityIncrement() {
        onAccessibilityIncrement?()
    }

    override func accessibilityDecrement() {
        onAccessibilityDecrement?()
    }
}

private final class PPMediaViewerZoomCanvasView: UIView {
    let scrollView = UIScrollView()
    let imageView = PPMediaViewerAccessibleImageView()
    let retryButton = UIButton(type: .system)

    var reduceMotion = false
    var onZoomStateChange: (() -> Void)?

    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private var imageTask: AppRemoteImageTask?
    private var loadIdentity = ""
    private var currentItemID = ""
    private var currentImageURL: String?
    private var currentAccessibilityLabel = ""
    private var accessibilityZoomBucket: Int?
    private var lastViewportSize = CGSize.zero
    private var isUpdatingGeometry = false
    private var isActive = false
    private weak var pagingScrollView: UIScrollView?
    private var pagingWasEnabled = true

    var hasDisplayableImage: Bool {
        imageView.image != nil
    }

    var normalizedZoomScale: CGFloat {
        let minimum = scrollView.minimumZoomScale
        guard minimum > 0, hasDisplayableImage else {
            return PPMediaViewerZoomMetrics.minimum
        }
        return min(
            max(
                scrollView.zoomScale / minimum,
                PPMediaViewerZoomMetrics.minimum
            ),
            PPMediaViewerZoomMetrics.maximum
        )
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViewHierarchy()
        configureAccessibility()
    }

    deinit {
        imageTask?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0,
              bounds.height > 0,
              hasDisplayableImage,
              !approximatelyEqual(bounds.size, lastViewportSize)
        else { return }
        updateZoomGeometry(preservingViewport: lastViewportSize != .zero)
        lastViewportSize = bounds.size
    }

    func configure(
        itemID: String,
        imageURL: String?,
        accessibilityLabel: String
    ) {
        currentAccessibilityLabel = accessibilityLabel
        imageView.accessibilityLabel = accessibilityLabel

        let identity = "\(itemID)|\(imageURL ?? "")"
        guard identity != loadIdentity else { return }

        loadIdentity = identity
        currentItemID = itemID
        currentImageURL = imageURL
        loadCurrentImage()
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if !active {
            restorePagingGesture()
        }
        isActive = active
        if !active {
            resetZoom(animated: false)
        } else {
            updatePagingAvailability()
        }
    }

    func setLayoutDirection(_ direction: LayoutDirection) {
        let isRightToLeft = direction == .rightToLeft || Language.isRTL()
        semanticContentAttribute = isRightToLeft
            ? .forceRightToLeft
            : .forceLeftToRight
        retryButton.semanticContentAttribute = semanticContentAttribute
    }

    func perform(_ action: PPMediaViewerZoomAction) {
        guard hasDisplayableImage else { return }
        switch action {
        case .zoomIn:
            setNormalizedZoom(
                normalizedZoomScale + PPMediaViewerZoomMetrics.step,
                around: visibleCenterInImage(),
                animated: !reduceMotion
            )
        case .zoomOut:
            setNormalizedZoom(
                normalizedZoomScale - PPMediaViewerZoomMetrics.step,
                around: visibleCenterInImage(),
                animated: !reduceMotion
            )
        case .reset:
            resetZoom(animated: !reduceMotion)
        }
    }

    func toggleZoom(around point: CGPoint) {
        guard hasDisplayableImage else { return }
        if normalizedZoomScale >
            PPMediaViewerZoomMetrics.minimum +
            PPMediaViewerZoomMetrics.epsilon
        {
            resetZoom(animated: !reduceMotion)
        } else {
            setNormalizedZoom(
                PPMediaViewerZoomMetrics.doubleTap,
                around: point,
                animated: !reduceMotion
            )
        }
    }

    func zoomDidChange() {
        centerImage()
        updatePanAvailability()
        updatePagingAvailability()
        updateAccessibilityValue()
        guard !isUpdatingGeometry else { return }
        onZoomStateChange?()
    }

    func zoomWillBegin() {
        guard isActive else { return }
        setPagingGestureEnabled(false)
    }

    func cancelImageLoad() {
        imageTask?.cancel()
        imageTask = nil
    }

    func prepareForDismantle() {
        cancelImageLoad()
        restorePagingGesture()
    }

    // MARK: Setup

    private func configureViewHierarchy() {
        backgroundColor = .black
        isMultipleTouchEnabled = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.decelerationRate = .fast
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        scrollView.panGestureRecognizer.isEnabled = false
        addSubview(scrollView)

        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        addSubview(loadingIndicator)

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.tintColor = .white
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.addTarget(
            self,
            action: #selector(retryImageLoad),
            for: .touchUpInside
        )
        addSubview(retryButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func configureAccessibility() {
        isAccessibilityElement = false
        imageView.isAccessibilityElement = false
        imageView.accessibilityTraits = [.image, .adjustable]
        imageView.onAccessibilityIncrement = { [weak self] in
            self?.perform(.zoomIn)
        }
        imageView.onAccessibilityDecrement = { [weak self] in
            self?.perform(.zoomOut)
        }

        loadingIndicator.isAccessibilityElement = true
        loadingIndicator.accessibilityLabel = PPMediaViewerL10n.text(
            "pp_media_viewer_loading",
            fallback: "Loading"
        )
        retryButton.accessibilityLabel = PPMediaViewerL10n.text(
            "pp_media_viewer_retry",
            fallback: "Retry"
        )
    }

    // MARK: Image Loading

    private func loadCurrentImage() {
        cancelImageLoad()
        resetForNewImage()
        showLoadingState()

        let expectedIdentity = loadIdentity
        imageTask = AppRemoteImagePipeline.load(
            urlString: currentImageURL,
            cacheKey: currentItemID,
            displaySize: nil,
            retryCount: 2
        ) { [weak self] image in
            guard let self, self.loadIdentity == expectedIdentity else {
                return
            }
            self.imageTask = nil
            if let image {
                self.install(image)
            } else {
                self.showFailureState()
            }
        }
    }

    private func install(_ image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        imageView.isAccessibilityElement = true
        loadingIndicator.stopAnimating()
        retryButton.isHidden = true
        lastViewportSize = .zero
        setNeedsLayout()
        layoutIfNeeded()

        if isActive, UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: imageView
            )
        }
    }

    private func showLoadingState() {
        imageView.isHidden = true
        imageView.isAccessibilityElement = false
        retryButton.isHidden = true
        loadingIndicator.startAnimating()
    }

    private func showFailureState() {
        imageView.isHidden = true
        imageView.isAccessibilityElement = false
        loadingIndicator.stopAnimating()
        updateRetryButtonAppearance()
        retryButton.isHidden = false
        if isActive, UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .layoutChanged,
                argument: retryButton
            )
        }
    }

    private func updateRetryButtonAppearance() {
        let title = PPMediaViewerL10n.text(
            "pp_media_viewer_retry",
            fallback: "Retry"
        )
        let symbol = UIImage.SymbolConfiguration(
            pointSize: 16,
            weight: .semibold
        )
        let baseFont = UIFont(name: "Beiruti-Bold", size: 16)
            ?? UIFont.preferredFont(forTextStyle: .headline)
        let scaledFont = UIFontMetrics(
            forTextStyle: .headline
        ).scaledFont(for: baseFont)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(
            systemName: "arrow.clockwise",
            withConfiguration: symbol
        )
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 20,
            bottom: 12,
            trailing: 20
        )
        configuration.background.backgroundColor = UIColor.white
            .withAlphaComponent(0.12)
        configuration.background.cornerRadius = 25
        configuration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = scaledFont
                return attributes
            }
        retryButton.configuration = configuration
    }

    @objc private func retryImageLoad() {
        loadCurrentImage()
    }

    private func resetForNewImage() {
        isUpdatingGeometry = true
        scrollView.layer.removeAllAnimations()
        imageView.layer.removeAllAnimations()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 1
        scrollView.zoomScale = 1
        scrollView.contentInset = .zero
        scrollView.contentOffset = .zero
        scrollView.contentSize = .zero
        imageView.transform = .identity
        imageView.frame = .zero
        imageView.image = nil
        accessibilityZoomBucket = nil
        lastViewportSize = .zero
        isUpdatingGeometry = false
        updatePanAvailability()
        updatePagingAvailability()
        updateAccessibilityValue()
        onZoomStateChange?()
    }

    // MARK: Zoom Geometry

    private func updateZoomGeometry(preservingViewport: Bool) {
        guard let image = imageView.image,
              image.size.width > 0,
              image.size.height > 0,
              bounds.width > 0,
              bounds.height > 0 else { return }

        let retainedScale = preservingViewport
            ? normalizedZoomScale
            : PPMediaViewerZoomMetrics.minimum
        let retainedCenter = preservingViewport
            ? normalizedVisibleCenter()
            : CGPoint(x: 0.5, y: 0.5)

        isUpdatingGeometry = true
        scrollView.minimumZoomScale = min(scrollView.minimumZoomScale, 1)
        scrollView.maximumZoomScale = max(scrollView.maximumZoomScale, 1)
        scrollView.setZoomScale(1, animated: false)
        imageView.transform = .identity
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size

        let fitScale = min(
            scrollView.bounds.width / image.size.width,
            scrollView.bounds.height / image.size.height
        )
        let minimumScale = max(fitScale, 0.0001)
        scrollView.minimumZoomScale = minimumScale
        scrollView.maximumZoomScale = minimumScale *
            PPMediaViewerZoomMetrics.maximum
        scrollView.setZoomScale(
            minimumScale * min(
                max(retainedScale, PPMediaViewerZoomMetrics.minimum),
                PPMediaViewerZoomMetrics.maximum
            ),
            animated: false
        )
        centerImage()
        restoreVisibleCenter(retainedCenter)
        isUpdatingGeometry = false
        updatePanAvailability()
        updatePagingAvailability()
        updateAccessibilityValue()
        onZoomStateChange?()
    }

    private func setNormalizedZoom(
        _ proposedScale: CGFloat,
        around point: CGPoint,
        animated: Bool
    ) {
        guard hasDisplayableImage,
              scrollView.minimumZoomScale > 0 else { return }
        let normalizedScale = min(
            max(proposedScale, PPMediaViewerZoomMetrics.minimum),
            PPMediaViewerZoomMetrics.maximum
        )
        let targetScale = scrollView.minimumZoomScale * normalizedScale

        if normalizedScale <=
            PPMediaViewerZoomMetrics.minimum +
            PPMediaViewerZoomMetrics.epsilon
        {
            scrollView.setZoomScale(
                scrollView.minimumZoomScale,
                animated: animated
            )
            return
        }

        let center = CGPoint(
            x: min(max(point.x, imageView.bounds.minX), imageView.bounds.maxX),
            y: min(max(point.y, imageView.bounds.minY), imageView.bounds.maxY)
        )
        let zoomSize = CGSize(
            width: scrollView.bounds.width / targetScale,
            height: scrollView.bounds.height / targetScale
        )
        let zoomRect = CGRect(
            x: center.x - zoomSize.width / 2,
            y: center.y - zoomSize.height / 2,
            width: zoomSize.width,
            height: zoomSize.height
        )
        scrollView.zoom(to: zoomRect, animated: animated)
    }

    private func resetZoom(animated: Bool) {
        guard hasDisplayableImage else {
            updatePanAvailability()
            onZoomStateChange?()
            return
        }
        scrollView.setZoomScale(
            scrollView.minimumZoomScale,
            animated: animated
        )
    }

    private func centerImage() {
        let horizontalInset = max(
            (scrollView.bounds.width - scrollView.contentSize.width) / 2,
            0
        )
        let verticalInset = max(
            (scrollView.bounds.height - scrollView.contentSize.height) / 2,
            0
        )
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    private func visibleCenterInImage() -> CGPoint {
        imageView.convert(
            CGPoint(
                x: scrollView.bounds.midX,
                y: scrollView.bounds.midY
            ),
            from: scrollView
        )
    }

    private func normalizedVisibleCenter() -> CGPoint {
        guard imageView.bounds.width > 0,
              imageView.bounds.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        let center = visibleCenterInImage()
        return CGPoint(
            x: min(max(center.x / imageView.bounds.width, 0), 1),
            y: min(max(center.y / imageView.bounds.height, 0), 1)
        )
    }

    private func restoreVisibleCenter(_ normalizedCenter: CGPoint) {
        let imagePoint = CGPoint(
            x: imageView.bounds.width * normalizedCenter.x,
            y: imageView.bounds.height * normalizedCenter.y
        )
        let pointInScroll = imageView.convert(imagePoint, to: scrollView)
        let proposedOffset = CGPoint(
            x: scrollView.contentOffset.x +
                pointInScroll.x - scrollView.bounds.midX,
            y: scrollView.contentOffset.y +
                pointInScroll.y - scrollView.bounds.midY
        )
        scrollView.setContentOffset(
            clampedContentOffset(proposedOffset),
            animated: false
        )
    }

    private func clampedContentOffset(_ proposed: CGPoint) -> CGPoint {
        let minimumX = -scrollView.contentInset.left
        let minimumY = -scrollView.contentInset.top
        let maximumX = max(
            minimumX,
            scrollView.contentSize.width - scrollView.bounds.width +
                scrollView.contentInset.right
        )
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height +
                scrollView.contentInset.bottom
        )
        return CGPoint(
            x: min(max(proposed.x, minimumX), maximumX),
            y: min(max(proposed.y, minimumY), maximumY)
        )
    }

    private func updatePanAvailability() {
        let canPan = hasDisplayableImage &&
            normalizedZoomScale >
                PPMediaViewerZoomMetrics.minimum +
                PPMediaViewerZoomMetrics.epsilon
        if scrollView.panGestureRecognizer.isEnabled != canPan {
            scrollView.panGestureRecognizer.isEnabled = canPan
        }
    }

    private func updatePagingAvailability() {
        guard isActive else { return }
        let isAtRest = normalizedZoomScale <=
            PPMediaViewerZoomMetrics.minimum +
            PPMediaViewerZoomMetrics.epsilon
        setPagingGestureEnabled(isAtRest)
    }

    private func setPagingGestureEnabled(_ enabled: Bool) {
        guard let pagingScrollView = resolvedPagingScrollView() else {
            return
        }
        if enabled {
            if pagingWasEnabled,
               !pagingScrollView.panGestureRecognizer.isEnabled {
                pagingScrollView.panGestureRecognizer.isEnabled = true
            }
        } else if pagingScrollView.panGestureRecognizer.isEnabled {
            pagingWasEnabled = true
            pagingScrollView.panGestureRecognizer.isEnabled = false
        }
    }

    private func restorePagingGesture() {
        guard let pagingScrollView else { return }
        pagingScrollView.panGestureRecognizer.isEnabled = pagingWasEnabled
        self.pagingScrollView = nil
        pagingWasEnabled = true
    }

    private func resolvedPagingScrollView() -> UIScrollView? {
        if let pagingScrollView { return pagingScrollView }
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView,
               scrollView !== self.scrollView {
                pagingScrollView = scrollView
                pagingWasEnabled = scrollView.panGestureRecognizer.isEnabled
                return scrollView
            }
            candidate = view.superview
        }
        return nil
    }

    private func updateAccessibilityValue() {
        imageView.accessibilityLabel = currentAccessibilityLabel
        let bucket = Int((normalizedZoomScale * 10).rounded())
        guard bucket != accessibilityZoomBucket else { return }
        accessibilityZoomBucket = bucket
        imageView.accessibilityValue = PPMediaViewerL10n.percentText(
            CGFloat(bucket) / 10
        )
    }

    private func approximatelyEqual(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 &&
            abs(lhs.height - rhs.height) < 0.5
    }
}

// MARK: - Video Player

private struct PPMediaViewerVideo: View {
    let url: URL
    let isActive: Bool
    let onSingleTap: () -> Void

    @StateObject private var model: PPMediaViewerVideoModel

    init(url: URL, isActive: Bool, onSingleTap: @escaping () -> Void) {
        self.url = url
        self.isActive = isActive
        self.onSingleTap = onSingleTap
        _model = StateObject(
            wrappedValue: PPMediaViewerVideoModel(url: url)
        )
    }

    var body: some View {
        ZStack {
            Color.black
            VideoPlayer(player: model.player)
                .onTapGesture {
                    onSingleTap()
                }

            switch model.state {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(
                        PPMediaViewerL10n.text(
                            "pp_media_viewer_loading",
                            fallback: "Loading"
                        )
                    )
            case .failed:
                Button {
                    model.retry()
                } label: {
                    Label(
                        PPMediaViewerL10n.text(
                            "pp_media_viewer_retry",
                            fallback: "Retry"
                        ),
                        systemImage: "arrow.clockwise"
                    )
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 16,
                            relativeTo: .headline
                        )
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .ppGlassSurface(
                        in: Capsule(),
                        tint: Color.black.opacity(0.18),
                        fallback: Color.black.opacity(0.85),
                        isInteractive: true
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(PPMediaViewerPressStyle())
                .contentShape(Capsule())
            case .ready:
                if !model.isPlaying {
                    Button {
                        model.play()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .ppGlassSurface(
                                in: Circle(),
                                tint: Color.black.opacity(0.18),
                                fallback: Color.black.opacity(0.85),
                                isInteractive: true
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(PPMediaViewerPressStyle())
                    .contentShape(Circle())
                    .accessibilityLabel(
                        PPMediaViewerL10n.text(
                            "pp_media_viewer_play",
                            fallback: "Play"
                        )
                    )
                }
            }
        }
        .onAppear {
            if isActive { model.play() }
        }
        .onChange(of: isActive) { active in
            active ? model.play() : model.pause()
        }
        .onDisappear {
            model.pause()
        }
    }
}

// MARK: - Video Player Model

@MainActor
private final class PPMediaViewerVideoModel: ObservableObject {
    let player = AVPlayer()

    enum State: Equatable {
        case loading, ready, failed
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isPlaying = false

    private let url: URL
    private var wantsToPlay = false
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init(url: URL) {
        self.url = url
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play() {
        wantsToPlay = true
        if player.currentItem == nil {
            configurePlayer()
            return
        }
        if state == .ready {
            player.play()
        }
    }

    func pause() {
        wantsToPlay = false
        player.pause()
    }

    func retry() {
        configurePlayer()
    }

    private func configurePlayer() {
        statusObservation = nil
        timeControlObservation = nil
        state = .loading
        isPlaying = false

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause

        statusObservation = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.state = .ready
                    if self.wantsToPlay { self.player.play() }
                case .failed:
                    self.state = .failed
                case .unknown:
                    self.state = .loading
                @unknown default:
                    self.state = .failed
                }
            }
        }

        timeControlObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.state = .ready
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    if self.wantsToPlay { self.state = .loading }
                case .paused:
                    self.isPlaying = false
                    if player.currentItem?.status == .readyToPlay {
                        self.state = .ready
                    }
                @unknown default:
                    self.isPlaying = false
                }
            }
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.player.seek(to: .zero)
                self.isPlaying = false
            }
        }
    }
}

// MARK: - Press Button Style

private struct PPMediaViewerPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed || !isEnabled
                    ? 1
                    : pressedScale
            )
            .opacity(
                !isEnabled
                    ? 0.48
                    : (configuration.isPressed ? 0.76 : 1)
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.10),
                value: configuration.isPressed
            )
    }
}

// MARK: - Localization

private enum PPMediaViewerL10n {
    @inline(__always)
    static func text(_ key: String, fallback: String) -> String {
        let localized = Language.get(key, alter: fallback)
        guard let localized, !localized.isEmpty, localized != key else {
            return fallback
        }
        return localized
    }

    static func counterText(current: Int, total: Int) -> String {
        "\(decimalText(current)) / \(decimalText(total))"
    }

    static func percentText(_ scale: CGFloat) -> String {
        let formatter = usesArabicLocale
            ? arabicPercentFormatter
            : englishPercentFormatter
        return formatter.string(from: NSNumber(value: Double(scale)))
            ?? "\(Int((scale * 100).rounded()))%"
    }

    static func decimalText(_ value: Int) -> String {
        let formatter = usesArabicLocale
            ? arabicDecimalFormatter
            : englishDecimalFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func mediaPositionText(current: Int, total: Int) -> String {
        let format = text(
            "pp_media_viewer_photo_position_format",
            fallback: "Photo %@ of %@"
        )
        return String(
            format: format,
            locale: appLocale,
            decimalText(current),
            decimalText(total)
        )
    }

    private static var appLocale: Locale {
        Locale(identifier: usesArabicLocale ? "ar" : "en")
    }

    private static var usesArabicLocale: Bool {
        (Language.currentLanguageCode() ?? "ar")
            .lowercased()
            .hasPrefix("ar")
    }

    private static let arabicDecimalFormatter = formatter(
        localeIdentifier: "ar",
        style: .decimal
    )
    private static let englishDecimalFormatter = formatter(
        localeIdentifier: "en",
        style: .decimal
    )
    private static let arabicPercentFormatter = formatter(
        localeIdentifier: "ar",
        style: .percent
    )
    private static let englishPercentFormatter = formatter(
        localeIdentifier: "en",
        style: .percent
    )

    private static func formatter(
        localeIdentifier: String,
        style: NumberFormatter.Style
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = style
        return formatter
    }
}

// MARK: - Convenience Bridge Extensions

extension PPMediaItem {
    /// Create from a `PPPetAdMediaItem`.
    init(petAd item: PPPetAdMediaItem) {
        self.init(
            id: item.id,
            imageURL: item.imageURL,
            videoURL: item.videoURL,
            blurHash: item.blurHash,
            isVideo: item.isVideo
        )
    }

    /// Create from a `PPAccessoryViewerMediaItem`.
    init(accessory item: PPAccessoryViewerMediaItem) {
        self.init(
            id: item.id,
            imageURL: item.imageURL,
            videoURL: item.videoURL,
            blurHash: item.blurHash,
            isVideo: item.isVideo
        )
    }

    /// Convert an array of `PPPetAdMediaItem` to shared items.
    static func from(petAdMedia items: [PPPetAdMediaItem]) -> [PPMediaItem] {
        items.map { PPMediaItem(petAd: $0) }
    }

    /// Convert an array of `PPAccessoryViewerMediaItem` to shared items.
    static func from(
        accessoryMedia items: [PPAccessoryViewerMediaItem]
    ) -> [PPMediaItem] {
        items.map { PPMediaItem(accessory: $0) }
    }
}
