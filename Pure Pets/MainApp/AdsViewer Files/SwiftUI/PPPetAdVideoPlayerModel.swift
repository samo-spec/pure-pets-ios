import AVFoundation
import Combine
import Foundation

@MainActor
final class PPPetAdVideoPlayerModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var state: PPPetAdVideoState = .loading
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
                    state = .ready
                    if wantsToPlay {
                        player.play()
                    }
                case .failed:
                    state = .failed
                case .unknown:
                    state = .loading
                @unknown default:
                    state = .failed
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
                    isPlaying = true
                    state = .ready
                case .waitingToPlayAtSpecifiedRate:
                    isPlaying = false
                    if wantsToPlay {
                        state = .loading
                    }
                case .paused:
                    isPlaying = false
                    if player.currentItem?.status == .readyToPlay {
                        state = .ready
                    }
                @unknown default:
                    isPlaying = false
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
                player.seek(to: .zero)
                isPlaying = false
            }
        }
    }
}
