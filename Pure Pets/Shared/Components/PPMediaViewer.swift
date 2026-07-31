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
    @State private var zoomCommand = PPMediaViewerZoomCommand(
        token: 0,
        action: .reset
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
            sendZoomCommand(.reset)
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
                onSingleTap: toggleChrome
            )
        }
    }

    func mediaAccessibilityLabel(index: Int) -> String {
        let label = PPMediaViewerL10n.text(
            "pp_media_viewer_photo",
            fallback: "Photo"
        )
        let of = PPMediaViewerL10n.text(
            "pp_media_viewer_of",
            fallback: "of"
        )
        return "\(label) \(index + 1) \(of) \(items.count)"
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
                        current: selection + 1,
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
                    action: onShare
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer()

            // Bottom controls
            if let current = currentItem, !current.isVideo {
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
                enabled: selection > 0
            ) {
                selection = max(selection - 1, 0)
            }

            Spacer(minLength: 4)

            chromeButton(
                symbol: "minus.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_out",
                    fallback: "Zoom out"
                )
            ) {
                sendZoomCommand(.zoomOut)
            }

            chromeButton(
                symbol: "1.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_reset_zoom",
                    fallback: "Reset zoom"
                )
            ) {
                sendZoomCommand(.reset)
            }

            chromeButton(
                symbol: "plus.magnifyingglass",
                label: PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_in",
                    fallback: "Zoom in"
                )
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
                enabled: selection < items.count - 1
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
            action: action
        )
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.36)
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

private struct PPMediaViewerZoomableImage: View {
    let item: PPMediaItem
    let accessibilityLabel: String
    let isActive: Bool
    let zoomCommand: PPMediaViewerZoomCommand
    @Binding var isActiveImageZoomed: Bool
    let onSingleTap: () -> Void

    @State private var committedScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedScale: CGFloat {
        min(max(committedScale * gestureScale, 1), 4)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = resolvedScale
            let offset = boundedOffset(
                CGSize(
                    width: committedOffset.width + gestureOffset.width,
                    height: committedOffset.height + gestureOffset.height
                ),
                scale: scale,
                viewport: proxy.size
            )

            AppRemoteImage(
                urlString: item.imageURL,
                cacheKey: item.id,
                displaySize: nil,
                contentMode: .fit
            ) {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    ProgressView()
                        .tint(.white)
                }
            } failurePlaceholder: {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 26, weight: .semibold))
                    Text(PPMediaViewerL10n.text(
                        "pp_media_viewer_retry",
                        fallback: "Retry"
                    ))
                    .font(
                        .custom(
                            "Beiruti-Bold",
                            size: 15,
                            relativeTo: .callout
                        )
                    )
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(Rectangle())
            .simultaneousGesture(magnificationGesture(viewport: proxy.size))
            .gesture(
                dragGesture(viewport: proxy.size),
                including: scale > 1.01 ? .all : .none
            )
        }
        .onTapGesture(count: 2) {
            setScale(committedScale > 1 ? 1 : 2.35)
        }
        .onTapGesture(count: 1, perform: onSingleTap)
        .onChange(of: zoomCommand) { command in
            guard isActive else { return }
            switch command.action {
            case .zoomIn:
                setScale(min(committedScale + 0.75, 4))
            case .zoomOut:
                setScale(max(committedScale - 0.75, 1))
            case .reset:
                setScale(1)
            }
        }
        .onChange(of: isActive) { active in
            if !active {
                setScale(1)
            } else {
                isActiveImageZoomed = committedScale > 1.01
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .accessibilityValue(
            "\(Int((resolvedScale * 100).rounded()))%"
        )
        .accessibilityAction(
            named: Text(
                PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_in",
                    fallback: "Zoom in"
                )
            )
        ) {
            setScale(min(committedScale + 0.75, 4))
        }
        .accessibilityAction(
            named: Text(
                PPMediaViewerL10n.text(
                    "pp_media_viewer_zoom_out",
                    fallback: "Zoom out"
                )
            )
        ) {
            setScale(max(committedScale - 0.75, 1))
        }
    }

    // MARK: Gestures

    private func magnificationGesture(
        viewport: CGSize
    ) -> some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let next = min(max(committedScale * value, 1), 4)
                committedScale = next
                committedOffset = boundedOffset(
                    committedOffset,
                    scale: next,
                    viewport: viewport
                )
                updateZoomState()
            }
    }

    private func dragGesture(
        viewport: CGSize
    ) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($gestureOffset) { value, state, _ in
                guard resolvedScale > 1.01 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard resolvedScale > 1.01 else {
                    committedOffset = .zero
                    return
                }
                committedOffset = boundedOffset(
                    CGSize(
                        width: committedOffset.width +
                            value.translation.width,
                        height: committedOffset.height +
                            value.translation.height
                    ),
                    scale: resolvedScale,
                    viewport: viewport
                )
            }
    }

    // MARK: Helpers

    private func boundedOffset(
        _ candidate: CGSize,
        scale: CGFloat,
        viewport: CGSize
    ) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = max(0, viewport.width * (scale - 1) / 2)
        let maxY = max(0, viewport.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(candidate.width, -maxX), maxX),
            height: min(max(candidate.height, -maxY), maxY)
        )
    }

    private func setScale(_ scale: CGFloat) {
        let changes = {
            committedScale = min(max(scale, 1), 4)
            if committedScale <= 1.01 {
                committedOffset = .zero
            }
            updateZoomState()
        }
        if reduceMotion {
            changes()
        } else {
            withAnimation(.easeInOut(duration: 0.24), changes)
        }
    }

    private func updateZoomState() {
        if isActive {
            isActiveImageZoomed = committedScale > 1.01
        }
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
        "\(current) / \(total)"
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
