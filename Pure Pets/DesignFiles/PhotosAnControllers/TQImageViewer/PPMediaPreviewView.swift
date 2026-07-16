import AVFoundation
import SwiftUI
import UIKit

@objc final class PPMediaPreviewFactory: NSObject {
    private static func hostController(rootView: AnyView) -> UIViewController {
        let controller = PPMediaPreviewHostController(rootView: rootView)
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .crossDissolve
        return controller
    }

    @objc(imageControllerWithImage:closeLabel:editLabel:shareLabel:onClose:onEdit:onShare:)
    static func imageController(
        image: UIImage,
        closeLabel: String,
        editLabel: String,
        shareLabel: String,
        onClose: @escaping () -> Void,
        onEdit: (() -> Void)?,
        onShare: (() -> Void)?
    ) -> UIViewController {
        let view = PPImagePreviewView(
            image: image,
            labels: .init(close: closeLabel, edit: editLabel, share: shareLabel),
            onClose: onClose,
            onEdit: onEdit,
            onShare: onShare,
            onSend: nil
        )
        return hostController(rootView: AnyView(view))
    }

    @objc(videoControllerWithURL:closeLabel:editLabel:retryLabel:onClose:onEdit:)
    static func videoController(
        url: URL,
        closeLabel: String,
        editLabel: String,
        retryLabel: String,
        onClose: @escaping () -> Void,
        onEdit: (() -> Void)?
    ) -> UIViewController {
        let view = PPVideoPreviewView(
            url: url,
            labels: .init(close: closeLabel, edit: editLabel, retry: retryLabel),
            onClose: onClose,
            onEdit: onEdit
        )
        return hostController(rootView: AnyView(view))
    }

    @objc(draftImageControllerWithImage:closeLabel:editLabel:sendLabel:onClose:onEdit:onSend:)
    static func draftImageController(
        image: UIImage,
        closeLabel: String,
        editLabel: String,
        sendLabel: String,
        onClose: @escaping () -> Void,
        onEdit: (() -> Void)?,
        onSend: @escaping (UIImage) -> Void
    ) -> UIViewController {
        let view = PPImagePreviewView(
            image: image,
            labels: .init(close: closeLabel, edit: editLabel, share: "", send: sendLabel),
            onClose: onClose,
            onEdit: onEdit,
            onShare: nil,
            onSend: onSend
        )
        return hostController(rootView: AnyView(view))
    }

    @objc(draftVideoControllerWithURL:closeLabel:editLabel:sendLabel:retryLabel:onClose:onEdit:onSend:)
    static func draftVideoController(
        url: URL,
        closeLabel: String,
        editLabel: String,
        sendLabel: String,
        retryLabel: String,
        onClose: @escaping () -> Void,
        onEdit: (() -> Void)?,
        onSend: @escaping (URL) -> Void
    ) -> UIViewController {
        let view = PPVideoPreviewView(
            url: url,
            labels: .init(close: closeLabel, edit: editLabel, retry: retryLabel, send: sendLabel),
            onClose: onClose,
            onEdit: onEdit,
            onSend: onSend
        )
        return hostController(rootView: AnyView(view))
    }
}

private final class PPMediaPreviewHostController: UIHostingController<AnyView> {
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.accessibilityViewIsModal = true
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }
}

private enum PPMediaPreviewTypography {
    private static let mediumName = "Beiruti-Medium"
    private static let boldName = "Beiruti-Bold"

    static let action = Font.custom(boldName, size: 17, relativeTo: .headline)
    static let actionSmall = Font.custom(boldName, size: 15, relativeTo: .callout)
    static let caption = Font.custom(mediumName, size: 12.5, relativeTo: .caption)

    static func attributedTitle(_ title: String, font: Font = action) -> AttributedString {
        var value = AttributedString(title)
        value.font = font
        return value
    }
}

private func PPMediaPreviewLocalized(_ key: String, fallback: String) -> String {
    let value = Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    if value.isEmpty || value == key { return fallback }
    return value
}

private struct PPImagePreviewLabels {
    let close: String
    let edit: String
    let share: String
    let send: String?

    init(close: String, edit: String, share: String, send: String? = nil) {
        self.close = close
        self.edit = edit
        self.share = share
        self.send = send
    }
}

private struct PPVideoPreviewLabels {
    let close: String
    let edit: String
    let retry: String
    let send: String?

    init(close: String, edit: String, retry: String, send: String? = nil) {
        self.close = close
        self.edit = edit
        self.retry = retry
        self.send = send
    }

    var play: String { PPMediaPreviewLocalized("media_preview_play", fallback: "Play") }
    var pause: String { PPMediaPreviewLocalized("media_preview_pause", fallback: "Pause") }
    var mute: String { PPMediaPreviewLocalized("media_preview_mute", fallback: "Mute") }
    var unmute: String { PPMediaPreviewLocalized("media_preview_unmute", fallback: "Unmute") }
}

private struct PPMediaChromeButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(PPMediaChromeButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PPMediaChromeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().fill(Color.black.opacity(0.16)))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.91 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct PPMediaPrimaryActionButton: View {
    let title: String
    let systemName: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                Text(PPMediaPreviewTypography.attributedTitle(title))
            }
                .font(PPMediaPreviewTypography.action)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(minHeight: 50)
                .background(.white, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PPMediaPrimaryActionButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

private struct PPMediaPrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct PPImagePreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    let image: UIImage
    let labels: PPImagePreviewLabels
    let onClose: () -> Void
    let onEdit: (() -> Void)?
    let onShare: (() -> Void)?
    let onSend: ((UIImage) -> Void)?

    @State private var chromeVisible = true
    @State private var appeared = false
    @State private var sendStarted = false
    @State private var scale: CGFloat = 1
    @State private var storedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var storedOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .accessibilityLabel(Text(labels.edit))
                .accessibilityAddTraits(.isImage)
                .gesture(magnificationGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2, perform: toggleZoom)
                .onTapGesture { withChromeAnimation { chromeVisible.toggle() } }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? scale : scale * 0.985)

            if chromeVisible {
                chrome
                    .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.34)) { appeared = true }
            }
        }
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: 10) {
                PPMediaChromeButton(systemName: "xmark", accessibilityLabel: labels.close, action: onClose)
                Spacer()
                if let onShare {
                    PPMediaChromeButton(systemName: "square.and.arrow.up", accessibilityLabel: labels.share, action: onShare)
                }
                if let onEdit {
                    PPMediaChromeButton(systemName: "slider.horizontal.3", accessibilityLabel: labels.edit, action: onEdit)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            Spacer()
            if let sendLabel = labels.send, let onSend {
                HStack {
                    Spacer()
                    PPMediaPrimaryActionButton(
                        title: sendLabel,
                        systemName: "paperplane.fill",
                        isDisabled: sendStarted
                    ) {
                        guard !sendStarted else { return }
                        sendStarted = true
                        onSend(image)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in scale = min(max(storedScale * value, 1), 5) }
            .onEnded { _ in
                storedScale = scale
                if scale <= 1 { resetTransform() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: storedOffset.width + value.translation.width,
                                height: storedOffset.height + value.translation.height)
            }
            .onEnded { _ in storedOffset = offset }
    }

    private func toggleZoom() {
        if scale > 1 { resetTransform() }
        else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { scale = 2.25 }
            storedScale = 2.25
        }
    }

    private func resetTransform() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
            scale = 1
            offset = .zero
        }
        storedScale = 1
        storedOffset = .zero
    }

    private func withChromeAnimation(_ changes: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2), changes)
    }
}

@MainActor
private final class PPVideoPreviewModel: ObservableObject {
    enum State { case loading, ready, failed }

    let player: AVPlayer
    @Published var state: State = .loading
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var statusObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        observe(item: item)
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func start() {
        guard state != .failed else { return }
        player.play()
        isPlaying = true
    }

    func togglePlayback() {
        isPlaying ? player.pause() : player.play()
        isPlaying.toggle()
    }

    func toggleMute() {
        player.isMuted.toggle()
        isMuted = player.isMuted
    }

    func seek(to value: Double) {
        guard duration > 0 else { return }
        player.seek(to: CMTime(seconds: value * duration, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func retry() {
        state = .loading
        player.seek(to: .zero)
        player.play()
    }

    private func observe(item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self.state = .ready
                case .failed: self.state = .failed
                default: self.state = .loading
                }
            }
        }
        playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in self?.isPlaying = player.timeControlStatus == .playing }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, self.duration > 0 else { return }
                self.progress = min(max(time.seconds / self.duration, 0), 1)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.player.seek(to: .zero)
                self?.progress = 0
            }
        }
    }
}

private struct PPVideoPreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let sourceURL: URL
    let labels: PPVideoPreviewLabels
    let onClose: () -> Void
    let onEdit: (() -> Void)?
    let onSend: ((URL) -> Void)?
    @StateObject private var model: PPVideoPreviewModel
    @State private var chromeVisible = true
    @State private var isSeeking = false
    @State private var sendStarted = false

    init(
        url: URL,
        labels: PPVideoPreviewLabels,
        onClose: @escaping () -> Void,
        onEdit: (() -> Void)?,
        onSend: ((URL) -> Void)? = nil
    ) {
        self.sourceURL = url
        self.labels = labels
        self.onClose = onClose
        self.onEdit = onEdit
        self.onSend = onSend
        _model = StateObject(wrappedValue: PPVideoPreviewModel(url: url))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PPPlayerLayerView(player: model.player)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { chromeVisible.toggle() } }

            stateOverlay

            if chromeVisible { chrome.transition(.opacity) }
        }
        .onAppear { model.start() }
        .onDisappear { model.player.pause() }
    }

    @ViewBuilder private var stateOverlay: some View {
        switch model.state {
        case .loading:
            ProgressView().tint(.white).controlSize(.large).accessibilityLabel(Text(labels.retry))
        case .failed:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 28)).foregroundStyle(.secondary)
                Button(action: model.retry) {
                    Text(PPMediaPreviewTypography.attributedTitle(labels.retry,
                                                                  font: PPMediaPreviewTypography.actionSmall))
                }
                .font(PPMediaPreviewTypography.actionSmall)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        case .ready:
            EmptyView()
        }
    }

    private var chrome: some View {
        VStack {
            HStack {
                PPMediaChromeButton(systemName: "xmark", accessibilityLabel: labels.close, action: onClose)
                Spacer()
                if let onEdit {
                    PPMediaChromeButton(systemName: "slider.horizontal.3", accessibilityLabel: labels.edit, action: onEdit)
                }
            }
            .padding(.horizontal, 18).padding(.top, 10)
            Spacer()
            VStack(spacing: 12) {
                Slider(value: Binding(get: { model.progress }, set: { model.progress = $0 }), in: 0...1,
                       onEditingChanged: { editing in isSeeking = editing; if !editing { model.seek(to: model.progress) } })
                    .tint(.white)
                HStack(spacing: 14) {
                    Text(time(model.progress * model.duration))
                        .font(PPMediaPreviewTypography.caption)
                        .monospacedDigit()
                    Spacer()
                    PPMediaChromeButton(systemName: model.isPlaying ? "pause.fill" : "play.fill",
                                        accessibilityLabel: model.isPlaying ? labels.pause : labels.play,
                                        action: model.togglePlayback)
                    PPMediaChromeButton(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                        accessibilityLabel: model.isMuted ? labels.unmute : labels.mute,
                                        action: model.toggleMute)
                    Spacer()
                    Text(time(model.duration))
                        .font(PPMediaPreviewTypography.caption)
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                if let sendLabel = labels.send, let onSend {
                    HStack {
                        Spacer()
                        PPMediaPrimaryActionButton(
                            title: sendLabel,
                            systemName: "paperplane.fill",
                            isDisabled: sendStarted
                        ) {
                            guard !sendStarted else { return }
                            sendStarted = true
                            model.player.pause()
                            onSend(sourceURL)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 14)
            .background(.linearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom))
        }
    }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

private struct PPPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PPPlayerUIView { let view = PPPlayerUIView(); view.player = player; return view }
    func updateUIView(_ view: PPPlayerUIView, context: Context) { view.player = player }
}

private final class PPPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    override init(frame: CGRect) { super.init(frame: frame); playerLayer.videoGravity = .resizeAspect }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
