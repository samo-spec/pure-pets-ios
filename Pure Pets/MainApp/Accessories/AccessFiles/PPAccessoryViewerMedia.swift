import AVFoundation
import AVKit
import Combine
import SwiftUI
import UIKit

struct PPAccessoryRemoteImageView: View {
    let urlString: String?
    let blurHash: String?
    let contentMode: ContentMode
    let accessibilityLabel: String
    var isAvatar: Bool = false
    var fallbackInitials: String? = nil
    var cacheKey: String? = nil
    var displaySize: CGSize? = nil
    var onImageLoaded: ((UIImage) -> Void)? = nil

    @State private var blurHashImage: UIImage?

    init(
        urlString: String?,
        blurHash: String?,
        contentMode: ContentMode,
        accessibilityLabel: String,
        isAvatar: Bool = false,
        fallbackInitials: String? = nil,
        cacheKey: String? = nil,
        displaySize: CGSize? = nil,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.urlString = urlString
        self.blurHash = blurHash
        self.contentMode = contentMode
        self.accessibilityLabel = accessibilityLabel
        self.isAvatar = isAvatar
        self.fallbackInitials = fallbackInitials
        self.cacheKey = cacheKey
        self.displaySize = displaySize
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        ZStack {
            if isAvatar {
                PPAccessoryPalette.brand.opacity(0.12)
            } else {
                PPAccessorySubviewBackground.mediaFill
            }

            AppRemoteImage(
                urlString: urlString,
                cacheKey: cacheKey,
                displaySize: displaySize,
                contentMode: isAvatar ? .fill : contentMode,
                showsRetryAction: !isAvatar,
                onImageLoaded: onImageLoaded
            ) {
                ZStack {
                    placeholder
                    if let blurHashImage {
                        Image(uiImage: blurHashImage)
                            .resizable()
                            .aspectRatio(
                                contentMode: isAvatar ? .fill : contentMode
                            )
                    }
                    if !isAvatar {
                        ProgressView()
                            .tint(PPAccessoryPalette.accent)
                            .accessibilityLabel(
                                PPAccessoryViewerL10n.text(
                                    "accessory_view_loading_image"
                                )
                            )
                    }
                }
            } failurePlaceholder: {
                if isAvatar {
                    avatarFallback
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 26, weight: .semibold))
                        Text(PPAccessoryViewerL10n.text("Retry"))
                            .font(PPAccessoryTypography.calloutBold)
                    }
                    .foregroundStyle(PPAccessoryPalette.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
            }
        }
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
            if isAvatar {
                avatarFallback
            } else {
                PPAccessorySubviewBackground.mediaFill
                Image(systemName: "photo")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(PPAccessoryPalette.inkSecondary.opacity(0.54))
            }
        }
    }

    private var avatarFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PPAccessoryPalette.brand.opacity(0.18),
                    PPAccessoryPalette.accent.opacity(0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let initials = cleanInitials(from: fallbackInitials), !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PPAccessoryPalette.brand)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(PPAccessoryPalette.brand.opacity(0.85))
            }
        }
    }

    private func cleanInitials(from text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let components = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 2, let first = components.first?.first, let second = components[1].first {
            return String([first, second]).uppercased()
        } else if let first = text.first {
            return String(first).uppercased()
        }
        return nil
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
            size: CGSize(width: 44, height: 44),
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

enum PPAccessoryVideoState {
    case loading
    case ready
    case failed
}

@MainActor
final class PPAccessoryVideoPlayerModel: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var state: PPAccessoryVideoState = .loading
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
        } else if state == .ready {
            player.play()
        }
    }

    func pause() {
        wantsToPlay = false
        player.pause()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func retry() {
        configurePlayer()
    }

    private func configurePlayer() {
        statusObservation = nil
        timeControlObservation = nil
        state = .loading
        isPlaying = false

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
                    if self.wantsToPlay {
                        self.player.play()
                    }
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
                    if self.wantsToPlay {
                        self.state = .loading
                    }
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
                self?.player.seek(to: .zero)
                self?.isPlaying = false
            }
        }
    }
}

struct PPAccessoryVideoView: View {
    let url: URL
    let isActive: Bool
    @StateObject private var model: PPAccessoryVideoPlayerModel

    init(url: URL, isActive: Bool) {
        self.url = url
        self.isActive = isActive
        _model = StateObject(
            wrappedValue: PPAccessoryVideoPlayerModel(url: url)
        )
    }

    var body: some View {
        ZStack {
            Color.black
            VideoPlayer(player: model.player)

            switch model.state {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .accessibilityLabel(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_loading_video"
                        )
                    )
            case .failed:
                Button {
                    model.retry()
                    if isActive {
                        model.play()
                    }
                } label: {
                    Label(
                        PPAccessoryViewerL10n.text("Retry"),
                        systemImage: "arrow.clockwise"
                    )
                    .font(PPAccessoryTypography.calloutBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .ppAccessorySubviewBackground(
                        PPAccessorySubviewBackground.videoChromeFill,
                        in: Capsule(),
                        stroke: Color.white.opacity(0.16)
                    )
                }
            case .ready:
                EmptyView()
            }
        }
        .onAppear {
            if isActive {
                model.play()
            }
        }
        .onChange(of: isActive) { active in
            active ? model.play() : model.pause()
        }
        .onDisappear {
            model.pause()
        }
    }
}

struct PPAccessoryFullScreenMediaViewer: View {
    let items: [PPAccessoryViewerMediaItem]
    @Binding var selection: Int
    let productTitle: String
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var chromeVisible = true
    @State private var dismissOffset: CGFloat = 0
    @State private var activeImageIsZoomed = false
    @State private var zoomCommand = PPAccessoryZoomCommand(
        token: 0,
        action: .reset
    )
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) {
                    index,
                    item in
                    media(item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dismissOffset)
            .opacity(dismissOpacity)
            .simultaneousGesture(dismissGesture)

            if chromeVisible {
                chrome
                    .transition(.opacity)
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
    }

    @ViewBuilder
    private func media(
        _ item: PPAccessoryViewerMediaItem,
        index: Int
    ) -> some View {
        if item.isVideo,
           let rawURL = item.videoURL,
           let url = URL(string: rawURL) {
            PPAccessoryVideoView(url: url, isActive: index == selection)
                .onTapGesture(perform: toggleChrome)
                .accessibilityLabel(mediaLabel(index: index))
                .accessibilityAddTraits(.isImage)
        } else {
            PPAccessoryZoomableImage(
                item: item,
                accessibilityLabel: mediaLabel(index: index),
                isActive: index == selection,
                zoomCommand: zoomCommand,
                isActiveImageZoomed: $activeImageIsZoomed,
                onSingleTap: toggleChrome
            )
        }
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: 14) {
                mediaButton(
                    symbol: "xmark",
                    label: PPAccessoryViewerL10n.text("Close"),
                    action: onDismiss
                )

                Spacer()

                Text(
                    PPAccessoryViewerL10n.formatted(
                        "accessory_view_media_count_spaced_format",
                        PPAccessoryViewerL10n.integer(selection + 1),
                        PPAccessoryViewerL10n.integer(items.count)
                    )
                )
                    .font(PPAccessoryTypography.captionBold)
                    .monospacedDigit()
                    .foregroundStyle(PPAccessoryPalette.ink)
                    .padding(.horizontal, 15)
                    .frame(minHeight: 42)
                    .ppAccessorySubviewBackground(
                        PPAccessorySubviewBackground.fullScreenChromeFill,
                        in: Capsule(),
                        stroke: Color.white.opacity(0.16),
                        lineWidth: 0.8
                    )

                mediaButton(
                    symbol: "square.and.arrow.up",
                    label: PPAccessoryViewerL10n.text("Share"),
                    action: onShare
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer()

            if currentItem?.isVideo != true {
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

    private var zoomControls: some View {
        HStack(spacing: 12) {
            pagingButton(
                symbol: "chevron.backward",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_previous_media"
                ),
                enabled: selection > 0
            ) {
                selection = max(selection - 1, 0)
            }

            Spacer(minLength: 4)

            mediaButton(
                symbol: "minus.magnifyingglass",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_zoom_out"
                )
            ) {
                sendZoomCommand(.zoomOut)
            }

            mediaButton(
                symbol: "1.magnifyingglass",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_reset_zoom"
                )
            ) {
                sendZoomCommand(.reset)
            }

            mediaButton(
                symbol: "plus.magnifyingglass",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_zoom_in"
                )
            ) {
                sendZoomCommand(.zoomIn)
            }

            Spacer(minLength: 4)

            pagingButton(
                symbol: "chevron.forward",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_next_media"
                ),
                enabled: selection < items.count - 1
            ) {
                selection = min(selection + 1, items.count - 1)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var pagingControls: some View {
        HStack {
            pagingButton(
                symbol: "chevron.backward",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_previous_media"
                ),
                enabled: selection > 0
            ) {
                selection = max(selection - 1, 0)
            }

            Spacer()

            pagingButton(
                symbol: "chevron.forward",
                label: PPAccessoryViewerL10n.text(
                    "accessory_view_next_media"
                ),
                enabled: selection < items.count - 1
            ) {
                selection = min(selection + 1, items.count - 1)
            }
        }
    }

    private func mediaButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PPAccessoryPalette.ink)
                .frame(width: 48, height: 48)
                .ppAccessorySubviewBackground(
                    PPAccessorySubviewBackground.fullScreenChromeFill,
                    in: Circle(),
                    stroke: Color.white.opacity(0.16),
                    lineWidth: 0.8
                )
        }
        .buttonStyle(PPAccessoryPressStyle(pressedScale: 0.90))
        .accessibilityLabel(label)
    }

    private func pagingButton(
        symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        mediaButton(
            symbol: symbol,
            label: label,
            action: action
        )
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.36)
    }

    private func toggleChrome() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            chromeVisible.toggle()
        }
    }

    private func mediaLabel(index: Int) -> String {
        PPAccessoryViewerL10n.formatted(
            "accessory_view_media_accessibility_format",
            productTitle,
            PPAccessoryViewerL10n.integer(index + 1),
            PPAccessoryViewerL10n.integer(items.count)
        )
    }

    private var currentItem: PPAccessoryViewerMediaItem? {
        guard items.indices.contains(selection) else { return nil }
        return items[selection]
    }

    private var dismissOpacity: Double {
        let progress = min(abs(dismissOffset) / 360, 0.45)
        return 1 - progress
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !activeImageIsZoomed,
                      abs(value.translation.height) >
                        abs(value.translation.width) * 1.2 else {
                    return
                }
                dismissOffset = value.translation.height
            }
            .onEnded { value in
                guard !activeImageIsZoomed else {
                    dismissOffset = 0
                    return
                }
                let projected = value.predictedEndTranslation.height
                if abs(value.translation.height) > 120 ||
                    abs(projected) > 220 {
                    onDismiss()
                    return
                }
                withAnimation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: 0.24)
                ) {
                    dismissOffset = 0
                }
            }
    }

    private func sendZoomCommand(
        _ action: PPAccessoryZoomAction
    ) {
        zoomCommand = PPAccessoryZoomCommand(
            token: zoomCommand.token + 1,
            action: action
        )
    }
}

private enum PPAccessoryZoomAction: Equatable {
    case zoomIn
    case zoomOut
    case reset
}

private struct PPAccessoryZoomCommand: Equatable {
    let token: Int
    let action: PPAccessoryZoomAction
}

private struct PPAccessoryZoomableImage: View {
    let item: PPAccessoryViewerMediaItem
    let accessibilityLabel: String
    let isActive: Bool
    let zoomCommand: PPAccessoryZoomCommand
    @Binding var isActiveImageZoomed: Bool
    let onSingleTap: () -> Void

    @State private var committedScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var committedOffset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            PPAccessoryRemoteImageView(
                urlString: item.imageURL,
                blurHash: item.blurHash,
                contentMode: .fit,
                accessibilityLabel: accessibilityLabel,
                cacheKey: item.id
            )
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
            setScale(committedScale > 1 ? 1 : 2.2)
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
        .accessibilityAction(
            named: Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_zoom_in"
                )
            )
        ) {
            setScale(min(committedScale + 0.75, 4))
        }
        .accessibilityAction(
            named: Text(
                PPAccessoryViewerL10n.text(
                    "accessory_view_zoom_out"
                )
            )
        ) {
            setScale(max(committedScale - 0.75, 1))
        }
    }

    private var resolvedScale: CGFloat {
        min(max(committedScale * gestureScale, 1), 4)
    }

    private func magnificationGesture(
        viewport: CGSize
    ) -> some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let nextScale = min(
                    max(committedScale * value, 1),
                    4
                )
                committedScale = nextScale
                committedOffset = boundedOffset(
                    committedOffset,
                    scale: nextScale,
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

    private func boundedOffset(
        _ candidate: CGSize,
        scale: CGFloat,
        viewport: CGSize
    ) -> CGSize {
        guard scale > 1 else { return .zero }
        let maximumX = max(0, viewport.width * (scale - 1) / 2)
        let maximumY = max(0, viewport.height * (scale - 1) / 2)
        return CGSize(
            width: min(max(candidate.width, -maximumX), maximumX),
            height: min(max(candidate.height, -maximumY), maximumY)
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
