import AVFoundation
import AVKit
import Combine
import SwiftUI
import UIKit

enum PPAccessoryImageLoadState {
    case idle
    case loading(placeholder: UIImage?)
    case loaded(UIImage)
    case failed
}

@MainActor
final class PPAccessoryImageLoader: ObservableObject {
    @Published private(set) var state: PPAccessoryImageLoadState = .idle

    private var requestID = UUID()
    private var currentURL: String?

    func load(urlString: String?, blurHash: String?) {
        let normalizedURL =
            urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHash =
            blurHash?.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentURL == normalizedURL, case .loaded = state {
            return
        }

        requestID = UUID()
        let activeRequestID = requestID
        currentURL = normalizedURL
        state = .loading(placeholder: nil)

        if let normalizedHash, !normalizedHash.isEmpty {
            PPBlurHashBridge.image(
                from: normalizedHash,
                size: CGSize(width: 44, height: 44),
                punch: 1
            ) { [weak self] placeholder in
                guard let self,
                      self.requestID == activeRequestID,
                      let placeholder else {
                    return
                }
                if normalizedURL?.isEmpty == false {
                    self.state = .loading(placeholder: placeholder)
                } else {
                    self.state = .loaded(placeholder)
                }
            }
        }

        guard let normalizedURL, !normalizedURL.isEmpty else {
            if normalizedHash?.isEmpty != false {
                state = .idle
            }
            return
        }

        PPAccessoryViewerLegacyBridge.loadImage(
            url: normalizedURL
        ) { [weak self] image in
            guard let self, self.requestID == activeRequestID else {
                return
            }
            self.state = image.map(PPAccessoryImageLoadState.loaded)
                ?? .failed
        }
    }

    func retry(blurHash: String?) {
        load(urlString: currentURL, blurHash: blurHash)
    }

    func cancel() {
        requestID = UUID()
    }
}

struct PPAccessoryRemoteImageView: View {
    let urlString: String?
    let blurHash: String?
    let contentMode: ContentMode
    let accessibilityLabel: String
    var isAvatar: Bool = false
    var fallbackInitials: String? = nil

    @StateObject private var loader = PPAccessoryImageLoader()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isAvatar {
                PPAccessoryPalette.brand.opacity(0.12)
            } else {
                PPAccessorySubviewBackground.mediaFill
            }

            switch loader.state {
            case .idle:
                placeholder
            case let .loading(image):
                if let image {
                    rendered(image)
                } else {
                    placeholder
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
            case let .loaded(image):
                rendered(image)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(
                                with: .scale(scale: 1.012)
                            )
                    )
            case .failed:
                if isAvatar {
                    avatarFallback
                } else {
                    Button {
                        loader.retry(blurHash: blurHash)
                    } label: {
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
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        PPAccessoryViewerL10n.text(
                            "accessory_view_image_retry_hint"
                        )
                    )
                }
            }
        }
        .clipped()
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.24),
            value: stateIdentity
        )
        .onAppear {
            loader.load(urlString: urlString, blurHash: blurHash)
        }
        .onChange(of: urlString) { value in
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

    private func rendered(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }

    private var stateIdentity: Int {
        switch loader.state {
        case .idle: return 0
        case .loading: return 1
        case .loaded: return 2
        case .failed: return 3
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
    let onDismiss: () -> Void
    let onShare: () -> Void

    @State private var chromeVisible = true
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
        } else {
            PPAccessoryZoomableImage(
                item: item,
                accessibilityLabel: mediaLabel(index: index),
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

                Text("\(selection + 1) / \(items.count)")
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

    private func toggleChrome() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            chromeVisible.toggle()
        }
    }

    private func mediaLabel(index: Int) -> String {
        "\(PPAccessoryViewerL10n.text("Photo")) \(index + 1) \(PPAccessoryViewerL10n.text("of")) \(items.count)"
    }
}

struct PPAccessoryZoomableImage: View {
    let item: PPAccessoryViewerMediaItem
    let accessibilityLabel: String
    let onSingleTap: () -> Void

    @State private var committedScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1

    var body: some View {
        PPAccessoryRemoteImageView(
            urlString: item.imageURL,
            blurHash: item.blurHash,
            contentMode: .fill,
            accessibilityLabel: accessibilityLabel
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .scaleEffect(min(max(committedScale * gestureScale, 1), 4))
        .gesture(
            MagnificationGesture()
                .updating($gestureScale) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    committedScale = min(
                        max(committedScale * value, 1),
                        4
                    )
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                committedScale = committedScale > 1 ? 1 : 2.2
            }
        }
        .onTapGesture(count: 1, perform: onSingleTap)
    }
}
